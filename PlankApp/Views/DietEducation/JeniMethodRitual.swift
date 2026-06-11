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

    // (bodyFocusPhrase deleted 2026-06-11 — bodyFocus died with the
    // custom-program doctrine; the day-1 plan page no longer promises
    // body-part targeting.)

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

    // MARK: - Day 1 — the welcome (muscle math + recomp window)

    /// v1.1 content arc (2026-06-11, founder-approved tone): welcome
    /// keeps its substance; banned-vocab sweep applied, bodyFocus
    /// promise removed (custom-program doctrine), recomp over-claim
    /// softened + cited.
    private static func day1Pages(user: JeniMethodUserContext) -> [LessonPage] {
        let isFatLoss = JeniMethodContent.goalFrame(for: user.goal) == .fatLossPrimary
        let word = identityFeelingWord(for: user)
        let openReframe = isFatLoss ? "this isn't a diet. it never was." : "this isn't a quick fix."
        return [
            LessonPage(
                id: "welcome",
                eyebrow: "welcome",
                headline: "\(namedPrefix(for: user))you're in.",
                italic: ["in"],
                body: "i'm jeni, and i'll be right here every day. five minutes a day. that's all i'm asking. each day i'll teach you one true thing about your body. then you live it. that's the whole method.",
                breathLine: "before we start: one slow breath. make the exhale the long part.",
                ctaLabel: "continue"
            ),
            LessonPage(
                id: "math",
                eyebrow: "the muscle math",
                headline: "muscle changes the math.",
                italic: ["math"],
                body: "\(openReframe) muscle spends about three times more energy at rest than fat does. the more of it you carry, the more your body spends every day, even sitting still. most plans get this backwards.",
                ctaLabel: "continue"
            ),
            LessonPage(
                id: "recomp",
                eyebrow: "the rare window",
                headline: "right now, you're in a rare window.",
                italic: ["rare window"],
                body: "shrink with eating-less alone and up to a quarter of what you lose can be muscle. less muscle, lower spend, and it creeps back. but if you're new to training, your body can lose fat and build muscle at the same time. researchers call it recomposition. let's not miss it.",
                citation: "weinheimer et al., obesity reviews (2010)",
                ctaLabel: "continue"
            ),
            LessonPage(
                id: "plan",
                eyebrow: "your plan",
                headline: "you showed up. that's who we are now.",
                italic: ["showed up"],
                body: "your plan is short on purpose. five minutes done well beats forty you skip. this is what \(word) looks like at the start.",
                ctaLabel: "start today's workout",
                isHandoff: true
            ),
        ]
    }

    // MARK: - Day 2 — snap it, don't count it (Burke 2011)

    private static func day2Pages(user: JeniMethodUserContext) -> [LessonPage] {
        return [
            LessonPage(
                id: "fact",
                eyebrow: "the camera trick",
                headline: "snap it. don't count it.",
                italic: ["count"],
                body: "people who keep track of what they eat lose about twice as much as people who don't. not because tracking changes the food. because seeing it does. no math, no judgment, no good or bad. one photo before you eat. that's the whole habit.",
                citation: "burke et al., j am diet assoc (2011)",
                breathLine: breathLine(day: 2),
                ctaLabel: "continue"
            ),
            LessonPage(
                id: "action",
                eyebrow: "today",
                headline: "snap your next plate.",
                italic: ["next plate"],
                body: "every food fits. the photo isn't a confession, it's a receipt. you're collecting evidence of a person who pays attention.",
                ctaLabel: "start today's workout",
                isHandoff: true
            ),
        ]
    }

    // MARK: - Day 3 — protein first (Leidy 2015)

    private static func day3Pages(user: JeniMethodUserContext) -> [LessonPage] {
        return [
            LessonPage(
                id: "fact",
                eyebrow: "one rule",
                headline: "protein first. that's the whole rule.",
                italic: ["protein first"],
                body: "protein is the keep-this-muscle signal while your weight changes, and it holds you full longer than anything else on the plate. a palm-sized portion each meal: eggs, yogurt, chicken, tofu, beans. no good foods, no bad foods. protein first, then everything else fits around it.",
                citation: "leidy et al., am j clin nutr (2015)",
                breathLine: breathLine(day: 3),
                ctaLabel: "continue"
            ),
            LessonPage(
                id: "action",
                eyebrow: "today",
                headline: "a palm of protein, every plate.",
                italic: ["every plate"],
                body: "pick the ones you actually like. and if your appetite runs small right now, protein goes first for exactly that reason. food is never something you owe. you eat because you're alive.",
                ctaLabel: "start today's workout",
                isHandoff: true
            ),
        ]
    }

    // MARK: - Day 4 — you can't out-move your plate (Pontzer 2016)

    private static func day4Pages(user: JeniMethodUserContext) -> [LessonPage] {
        return [
            LessonPage(
                id: "fact",
                eyebrow: "the honest math",
                headline: "you can't out-move your plate.",
                italic: ["out-move"],
                body: "scientists tracked people who move a lot all day. their bodies quietly spend less elsewhere to even it out, so the treadmill number flatters. movement is still the best thing we know for keeping weight off and your head clear. but the number itself? that's decided mostly at the table.",
                citation: "pontzer et al., current biology (2016)",
                breathLine: breathLine(day: 4),
                ctaLabel: "continue"
            ),
            LessonPage(
                id: "action",
                eyebrow: "today",
                headline: "let the plates move the number.",
                italic: ["plates"],
                body: "move for the keeping, eat for the changing. snap what's on your plate today, that's where the math lives.",
                ctaLabel: "start today's workout",
                isHandoff: true
            ),
        ]
    }

    // MARK: - Day 5 — the scale is moody (Helander 2014)

    private static func day5Pages(user: JeniMethodUserContext) -> [LessonPage] {
        return [
            LessonPage(
                id: "fact",
                eyebrow: "scale literacy",
                headline: "the scale is moody. the trend is honest.",
                italic: ["moody"],
                body: "your weight swings a couple of pounds in a day. water, salt, your cycle, when you last ate. none of it is fat. a single morning number is weather. the line through your week is climate. that's the only number we read.",
                citation: "helander et al., plos one (2014)",
                breathLine: breathLine(day: 5),
                ctaLabel: "continue"
            ),
            LessonPage(
                id: "action",
                eyebrow: "today",
                headline: "step on. write it down. walk away.",
                italic: ["walk away"],
                body: "log it and let the trend do the reading. an up day changes nothing. you weigh in to feed the line, not to get graded.",
                ctaLabel: "start today's workout",
                isHandoff: true
            ),
        ]
    }

    // MARK: - Day 6 — walk right after you eat (Engeroff 2023)

    private static func day6Pages(user: JeniMethodUserContext) -> [LessonPage] {
        let word = identityFeelingWord(for: user)
        return [
            LessonPage(
                id: "fact",
                eyebrow: "tiny, but mighty",
                headline: "walk right after you eat.",
                italic: ["right after"],
                body: "a slow walk in the first hour after a meal calms your blood-sugar spike more than the same walk done earlier. and the sooner you go, the better it works. no pace goal, no distance. just don't sit straight back down. ten easy minutes is the whole thing.",
                citation: "engeroff et al., sports medicine (2023)",
                breathLine: breathLine(day: 6),
                ctaLabel: "continue"
            ),
            LessonPage(
                id: "action",
                eyebrow: "today",
                headline: "after your biggest meal, walk ten easy minutes.",
                italic: ["ten easy minutes"],
                body: "around the block, around the kitchen, doesn't matter. \(word) is built from small, repeatable things. this is one.",
                ctaLabel: "start today's workout",
                isHandoff: true
            ),
        ]
    }

    // MARK: - Day 7 — lighter days (the quiet mark)

    private static func day7Pages(user: JeniMethodUserContext) -> [LessonPage] {
        return [
            LessonPage(
                id: "fact",
                eyebrow: "your quiet mark",
                headline: "some days land lighter.",
                italic: ["lighter"],
                body: "when a day's plates land under what your body spent, becoming gives it a quiet mark. it's a note, never a grade. days without the mark say nothing at all. and a barely-eaten day never earns it: the mark only counts when you're fed and under, gently.",
                citation: "the math: your size and age, your steps, your sessions",
                breathLine: breathLine(day: 7),
                ctaLabel: "continue"
            ),
            LessonPage(
                id: "action",
                eyebrow: "this week",
                headline: "collect them slowly.",
                italic: ["slowly"],
                body: "one or two a week moves the trend. chasing seven is the old way, and it never held. fed and gentle wins.",
                ctaLabel: "start today's workout",
                isHandoff: true
            ),
        ]
    }

    // MARK: - Day 8 — the comeback (Polivy & Herman + Adams & Leary)

    /// Merge of the old d8 (what-the-hell trap) + d9 (self-compassion
    /// return) — one behavior taught twice became one lesson.
    private static func day8Pages(user: JeniMethodUserContext) -> [LessonPage] {
        let word = identityFeelingWord(for: user)
        return [
            LessonPage(
                id: "fact",
                eyebrow: "the trap",
                headline: "one slip doesn't undo you. the story does.",
                italic: ["the story"],
                body: "psychologists call it the what-the-hell effect. you miss once, decide you've blown it, and that thought is what makes you quit. the missed day barely mattered. believing it ruined everything is what does the damage.",
                citation: "polivy & herman · restraint theory",
                breathLine: breathLine(day: 8),
                ctaLabel: "continue"
            ),
            LessonPage(
                id: "action",
                eyebrow: "the return",
                headline: "come back small. come back kind.",
                italic: ["kind"],
                body: "being hard on yourself after a slip makes quitting more likely, not less. women who met a setback with self-kindness came back faster. so next time: say it gently, do one tiny thing. the return is the whole skill, and \(word) is how fast you come back.",
                citation: "adams & leary (2007)",
                ctaLabel: "start today's workout",
                isHandoff: true
            ),
        ]
    }

    // MARK: - Day 9 — food noise (Balban 2023)

    private static func day9Pages(user: JeniMethodUserContext) -> [LessonPage] {
        return [
            LessonPage(
                id: "fact",
                eyebrow: "name it",
                headline: "food noise isn't hunger.",
                italic: ["hunger"],
                body: "that loop where you're thinking about snacks an hour after lunch? it has a name now, and it spikes with stress. five minutes of slow, exhale-heavy breathing measurably lowers the stress response. you can't argue with the loop. you can breathe under it.",
                citation: "balban et al., cell reports medicine (2023)",
                breathLine: breathLine(day: 9),
                ctaLabel: "continue"
            ),
            LessonPage(
                id: "action",
                eyebrow: "next time it's loud",
                headline: "breathe first. then decide.",
                italic: ["then decide"],
                body: "open your breath session, two minutes, long exhales. still want it after? have it. it fits. the breath isn't a no. it's a pause you own.",
                ctaLabel: "start today's workout",
                isHandoff: true
            ),
        ]
    }

    // MARK: - Day 10 — sleep is the multiplier (Spiegel + Nedeltcheva)

    private static func day10Pages(user: JeniMethodUserContext) -> [LessonPage] {
        let word = identityFeelingWord(for: user)
        return [
            LessonPage(
                id: "fact",
                eyebrow: "the multiplier",
                headline: "sleep decides if this works.",
                italic: ["sleep"],
                body: "under-slept, your hunger hormones shift by morning. you wake hungrier and reach for sugar without noticing. in one study, short sleep cut the fat share of weight lost nearly in half. your plan already paces itself around the sleep you told us about.",
                citation: "spiegel (2004) · nedeltcheva (2010)",
                breathLine: breathLine(day: 10),
                ctaLabel: "continue"
            ),
            LessonPage(
                id: "action",
                eyebrow: "tonight",
                headline: "pick a bedtime and protect it.",
                italic: ["protect it"],
                body: "phone out of the room thirty minutes before. the wind-down breath is built for exactly this hour. \(word) feels like being rested.",
                ctaLabel: "start today's workout",
                isHandoff: true
            ),
        ]
    }

    // MARK: - Day 11 — the quiet 7,500 (Paluch 2022 + Stamatakis 2022)

    /// Merge of the old d3 (NEAT) + d12 (exercise snacks) — untracked
    /// movement is one idea, anchored on the steps rail's 7,500.
    private static func day11Pages(user: JeniMethodUserContext) -> [LessonPage] {
        return [
            LessonPage(
                id: "fact",
                eyebrow: "the quiet engine",
                headline: "your day moves more than your workout.",
                italic: ["your day"],
                body: "standing, stairs, carrying things, the walk you didn't count. for most women it adds up to more than a session, every day. around seven and a half thousand steps is where the long-term numbers settle, no marathon required. and fast little bursts count double.",
                citation: "paluch et al., lancet public health (2022) · stamatakis et al. (2022)",
                breathLine: breathLine(day: 11),
                ctaLabel: "continue"
            ),
            LessonPage(
                id: "action",
                eyebrow: "today",
                headline: "find two minutes, once an hour.",
                italic: ["once an hour"],
                body: "stairs like you mean it, groceries in one trip, a lap of the kitchen. the quiet engine runs on exactly this.",
                ctaLabel: "start today's workout",
                isHandoff: true
            ),
        ]
    }

    // MARK: - Day 12 — small beats heroic (NWCR + Keating 2017)

    /// Old d6 with the enjoyment finding folded into the action page.
    private static func day12Pages(user: JeniMethodUserContext) -> [LessonPage] {
        return [
            LessonPage(
                id: "fact",
                eyebrow: "the rule that wins",
                headline: "small you'll do beats heroic you won't.",
                italic: ["small you'll do"],
                body: "you came back. honestly, that's most of the whole thing. in the long-term registries, the people who keep weight off aren't the ones who went hardest. they're the ones who kept showing up. five minutes you actually do beats forty-five you skip. even one rep is more than zero.",
                citation: "national weight control registry",
                breathLine: breathLine(day: 12),
                ctaLabel: "continue"
            ),
            LessonPage(
                id: "action",
                eyebrow: "today",
                headline: "pick the version you don't dread.",
                italic: ["don't dread"],
                body: "easy counts. enjoyment isn't a bonus, it's the active ingredient. five minutes you'll actually do, again tomorrow. that's the secret.",
                citation: "keating et al., obesity reviews (2017)",
                ctaLabel: "start today's workout",
                isHandoff: true
            ),
        ]
    }

    // MARK: - Day 13 — sixty-six days (Lally 2010)

    private static func day13Pages(user: JeniMethodUserContext) -> [LessonPage] {
        let word = identityFeelingWord(for: user)
        return [
            LessonPage(
                id: "fact",
                eyebrow: "the real timeline",
                headline: "it takes about sixty-six days. and that's okay.",
                italic: ["sixty-six days"],
                body: "you've heard it takes twenty-one days to build a habit. that's a myth. researchers tracked people forming a new habit and the real average was about sixty-six days. the best part: missing one day didn't break the process at all. we're not chasing perfect. we're chasing most days.",
                citation: "lally et al., eur j social psychology (2010)",
                breathLine: breathLine(day: 13),
                ctaLabel: "continue"
            ),
            LessonPage(
                id: "action",
                eyebrow: "today",
                headline: "aim for most days, not every day.",
                italic: ["most days"],
                body: "one miss is a non-event. truly. \(word) isn't a streak you can shatter. it's a direction you keep facing.",
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
                eyebrow: "one last thing",
                headline: "you can always begin again.",
                italic: ["always"],
                body: "you made it through the method. here's the part that keeps it going for good. any day can be a fresh start. a monday, the first of a month, a random tuesday. we naturally find more motivation at these clean-slate moments, but you don't have to wait for one. you can decide today is the line.",
                citation: "dai, milkman & riis (2014)",
                breathLine: breathLine(day: 14),
                ctaLabel: "continue"
            ),
            LessonPage(
                id: "action",
                eyebrow: "from here",
                headline: "name your one tiny thing for tomorrow.",
                italic: ["one tiny thing"],
                body: "say it with a when: 'after my morning coffee, i'll move.' from here it's the daily rhythm, one day at a time. \(word) isn't a finish line. it's who you're becoming.",
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

    /// Rotating one-line intentions for the generic warmup, picked by
    /// day-of-year so consecutive days differ. Program-wide (plates +
    /// walks + form), not workout-only.
    private static func dailyIntention(for date: Date) -> String {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 0
        switch day % 3 {
        case 0:  return "one thing today: quality over speed. a good slow rep beats three sloppy fast ones."
        case 1:  return "one thing today: protein first at your next meal. everything else fits around it."
        default: return "one thing today: ten easy minutes after your biggest meal. that's the whole assignment."
        }
    }
}
