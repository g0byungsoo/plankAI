import Foundation
import PlankSync

// MARK: - RepEngine (app v3 phase 3 — the method becomes practice)
//
// docs/app_v3/01_FEATURE_VERDICTS.md §Method. The daily Method moment
// is THE REP: a 20-40 second decision practice — a scenario from her
// real life, two or three doors, a warm mechanism line behind every
// door (no wrong answers — flexible restraint IS the curriculum), and
// the reader one quiet tap deeper.
//
// Content: the doc-22 ten authored as interactive doors, keyed to
// their canonical manifest days, plus one fallback per pillar so
// every lesson day carries a rep. The full 84-slot authoring pass is
// founder-present work (the table is the template).

struct MethodRep: Equatable {
    struct Door: Equatable {
        let label: String
        /// The mechanism line that rises when she chooses this door.
        let response: String
        /// Optional next-smallest-action the door offers after the
        /// response ("sixty seconds" → breath).
        var route: AppRouter.Route? = nil
        var chatSeed: String? = nil
    }

    let id: String
    let scenario: String
    let scenarioItalic: [String]
    let doors: [Door]
}

enum RepEngine {

    /// The rep for a resolved lesson: exact canonical-day match first,
    /// then the slot's leading pillar, then the begin-again default.
    static func rep(for ref: ResolvedLessonRef) -> MethodRep {
        if let exact = byCanonicalDay[ref.slot.canonicalDay] { return exact }
        if let fallback = byPillar[ref.slot.primaryPillar] { return fallback }
        return beginAgainRep
    }

    // MARK: - The doc-22 ten (canonical-day keyed)

    static let byCanonicalDay: [Int: MethodRep] = [
        2: MethodRep(
            id: "craving_wave",
            scenario: "9pm. the kitchen is calling.",
            scenarioItalic: ["calling"],
            doors: [
                .init(
                    label: "ride the wave for sixty seconds",
                    response: "waves crest inside two minutes. you just watched one pass instead of feeding it.",
                    route: .breath
                ),
                .init(
                    label: "eat it, gently",
                    response: "permission is allowed. a real plate, slow bites, zero verdicts."
                ),
                .init(
                    label: "name what i'm feeling first",
                    response: "'activated' isn't 'hungry.' naming it changes the channel the body speaks on."
                ),
            ]
        ),
        3: MethodRep(
            id: "all_or_nothing",
            scenario: "you ate the cookies. the write-off voice starts.",
            scenarioItalic: ["write-off"],
            doors: [
                .init(
                    label: "the day is ruined anyway",
                    response: "that voice is the what-the-hell effect, and it's lying about the math. cookies were a moment, not a verdict."
                ),
                .init(
                    label: "the next bite resets it",
                    response: "exactly. the day is not pass-fail, and nothing is owed back."
                ),
            ]
        ),
        16: MethodRep(
            id: "deficit_whisper",
            scenario: "week three. the crash-diet voice says this is too easy.",
            scenarioItalic: ["too easy"],
            doors: [
                .init(
                    label: "make it harder",
                    response: "the crash feels productive because it hurts. the whisper works because it doesn't."
                ),
                .init(
                    label: "let it stay quiet",
                    response: "a few hundred calories, held gently for months, outruns any two-week war."
                ),
            ]
        ),
        19: MethodRep(
            id: "scale_morning",
            scenario: "the scale is up two pounds overnight.",
            scenarioItalic: ["overnight"],
            doors: [
                .init(
                    label: "panic a little",
                    response: "two pounds of chemistry: glycogen, salt, hormones. your body didn't change overnight. the line already knows."
                ),
                .init(
                    label: "read the line, not the dot",
                    response: "that's trend literacy. the week decides, never the morning.",
                    route: .trend
                ),
            ]
        ),
        25: MethodRep(
            id: "protein_protection",
            scenario: "small appetite today. one plate, maybe.",
            scenarioItalic: ["one plate"],
            doors: [
                .init(
                    label: "protein first on that plate",
                    response: "when weight moves fast, protein tells your body: take from storage, keep the structure."
                ),
                .init(
                    label: "skip it, bank the day",
                    response: "quiet days still need their protein. eating enough is the strategy, not the failure."
                ),
            ]
        ),
        33: MethodRep(
            id: "sideways_day",
            scenario: "the day went sideways. the body wants dense and fast.",
            scenarioItalic: ["sideways"],
            doors: [
                .init(
                    label: "sixty seconds first, then decide",
                    response: "that's changing the channel. then, if you're still hungry, eat, in that order, once.",
                    route: .breath
                ),
                .init(
                    label: "eat while activated",
                    response: "it happens, and it isn't a failure. next wave, try the sequence: breath, then the decision."
                ),
            ]
        ),
        40: MethodRep(
            id: "easiest_lever",
            scenario: "no energy for anything today.",
            scenarioItalic: ["anything"],
            doors: [
                .init(
                    label: "one call with the phone in your pocket",
                    response: "your legs cover the gap on the days the kitchen wins. no outfit, no recovery, no motivation window."
                ),
                .init(
                    label: "write the day off",
                    response: "the ring counts even the small hours. quiet days still move. that's the whole trick."
                ),
            ]
        ),
        47: MethodRep(
            id: "maintenance_season",
            scenario: "the loss is done. the finish-line feeling is gone.",
            scenarioItalic: ["finish-line"],
            doors: [
                .init(
                    label: "find the next war",
                    response: "keeping runs on rhythm, not adrenaline. the band, up a little, down a little, is how it holds."
                ),
                .init(
                    label: "name my band with jeni",
                    response: "inside it, nothing to fix. that's the skill now.",
                    chatSeed: "they want to name their maintenance band. the range where they don't react. help them set it gently."
                ),
            ]
        ),
        61: MethodRep(
            id: "begin_again",
            scenario: "four days away. the app is open again.",
            scenarioItalic: ["open again"],
            doors: [
                .init(
                    label: "apologize and catch up",
                    response: "no catch-up is owed. a restart costs one small action, not a confession."
                ),
                .init(
                    label: "add your next meal",
                    response: "that's the whole re-entry.",
                    route: .snap
                ),
            ]
        ),
        75: MethodRep(
            id: "becoming_her",
            scenario: "someone asks what changed this year.",
            scenarioItalic: ["changed"],
            doors: [
                .init(
                    label: "the weight",
                    response: "the number moved because the defaults moved. the defaults are you now."
                ),
                .init(
                    label: "the way i talk to myself",
                    response: "identity is a ledger of small kept things. it's been compounding since day one."
                ),
            ]
        ),
    ]

    // MARK: - Pillar fallbacks (every lesson day carries a rep)

    static let byPillar: [PillarId: MethodRep] = [
        .P1: MethodRep(
            id: "p1_voice",
            scenario: "the inner critic has the mic tonight.",
            scenarioItalic: ["the mic"],
            doors: [
                .init(
                    label: "let them talk",
                    response: "they use the same five sentences they’ve used since you were twelve. noticing that is the skill."
                ),
                .init(
                    label: "hand jeni the mic",
                    response: "borrowed kindness counts while yours is quiet.",
                    chatSeed: "their inner critic is loud tonight. one gentle reframe, then one small anchor for the evening."
                ),
            ]
        ),
        .P2: MethodRep(
            id: "p2_enough",
            scenario: "full, but the plate isn't empty.",
            scenarioItalic: ["full"],
            doors: [
                .init(
                    label: "stop here",
                    response: "enough is a skill, not a waste. the plate did its job."
                ),
                .init(
                    label: "finish it anyway",
                    response: "noticing you noticed IS the rep. the pause gets easier every plate."
                ),
            ]
        ),
        .P3: MethodRep(
            id: "p3_kind_line",
            scenario: "today's report card, by the old rules: messy.",
            scenarioItalic: ["messy"],
            doors: [
                .init(
                    label: "grade it anyway",
                    response: "shame is a documented risk, not a motivator. kindness is the strategy, not the reward."
                ),
                .init(
                    label: "one kind line instead",
                    response: "that's the reset, done."
                ),
            ]
        ),
        .P4: MethodRep(
            id: "p4_mirror",
            scenario: "the mirror had opinions today.",
            scenarioItalic: ["opinions"],
            doors: [
                .init(
                    label: "argue with it",
                    response: "mirrors report light, not worth. bodies lag the work; the mirror lags the body."
                ),
                .init(
                    label: "let the ledger answer",
                    response: "kept days, quiet resets, plates that fit. the evidence outranks the glass."
                ),
            ]
        ),
        .P5: MethodRep(
            id: "p5_short_night",
            scenario: "five hours of sleep and a long list.",
            scenarioItalic: ["five hours"],
            doors: [
                .init(
                    label: "push through on willpower",
                    response: "under-slept days spend muscle on hard plans. today runs gentler on purpose."
                ),
                .init(
                    label: "downshift for sixty seconds",
                    response: "the exhale is the brake your day actually has.",
                    route: .breath
                ),
            ]
        ),
        .P6: MethodRep(
            id: "p6_band",
            scenario: "the loss is done. the finish-line feeling is gone.",
            scenarioItalic: ["finish-line"],
            doors: [
                .init(
                    label: "find the next war",
                    response: "keeping runs on rhythm, not adrenaline. the band is the win condition."
                ),
                .init(
                    label: "name my band with jeni",
                    response: "inside it, nothing to fix. that's the skill now.",
                    chatSeed: "they want to name their maintenance band. the range where they don't react. help them set it gently."
                ),
            ]
        ),
    ]

    static let beginAgainRep = MethodRep(
        id: "default_begin_again",
        scenario: "a new day, no script.",
        scenarioItalic: ["no script"],
        doors: [
            .init(
                label: "wait for motivation",
                response: "motivation follows action more often than it leads it. small first, feeling second."
            ),
            .init(
                label: "one small kept thing",
                response: "that's the whole pattern. everything else is compounding."
            ),
        ]
    )
}

// MARK: - MethodResolver (ONE lesson resolution, three former copies)
//
// TodayModules.openLesson/lessonTitle, TodayModuleHost.coverContent,
// and BecomingView.resolvedLesson each re-derived cadence → ordinal →
// service lookup — two of them with `CohortFlags.fromAppStorage()`,
// the zero-writer reader CohortStore was built to replace (cohort
// lesson variants silently resolved on defaults there).

enum MethodResolver {

    struct Resolution {
        let ref: ResolvedLessonRef
        /// Lesson-day ordinal (cadence-compressed program day).
        let ordinal: Int
        /// Total lesson days the arc compresses into.
        let lessonTotal: Int
    }

    /// Today's lesson, nil on non-lesson days. `journeyFallback` keeps
    /// Becoming's behavior: on a non-lesson day, resolve the most
    /// recent lesson-day instead of nothing.
    @MainActor
    static func resolve(
        plan: ProgramPlanRecord?,
        programDay: Int,
        journeyFallback: Bool = false
    ) -> Resolution? {
        guard let plan else { return nil }
        let tier = IntensityTier(rawValue: plan.intensityTier) ?? .medium
        let cadence = IntensityProfile.from(tier: tier).lessonCadence
        let lessonTotal = PrescriptionEngineV2.totalLessonDays(
            totalDays: plan.totalDays, cadence: cadence
        )
        var ordinal = PrescriptionEngineV2.lessonOrdinal(
            programDay: programDay, cadence: cadence
        )
        if ordinal == nil, journeyFallback {
            ordinal = max(1, PrescriptionEngineV2.totalLessonDays(
                totalDays: min(programDay, plan.totalDays), cadence: cadence
            ))
        }
        guard let ordinal else { return nil }
        guard let ref = CBTCurriculumService.shared.lesson(
            forProgramDay: ordinal,
            totalDays: lessonTotal,
            cohort: CohortStore.curriculumFlags()
        ) else { return nil }
        return Resolution(ref: ref, ordinal: ordinal, lessonTotal: lessonTotal)
    }

    /// Working titles carry [italic] markers + asterisks — one cleaner.
    static func cleanTitle(_ raw: String) -> String {
        raw.replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
            .replacingOccurrences(of: "*", with: "")
            .lowercased()
    }
}
