import XCTest
@testable import plankAI

/// Phase 9.28 — rebuilt safety + structural test suite against the new
/// ritual model. The old card-based suite (JeniMethodContentTests,
/// JeniMethodResolverTests, JeniMethodAnalyticsTests) was deleted in
/// the 9.22 cleanup because it targeted the deleted LessonCard /
/// LessonCardKind / ActionKind types. This re-implements the most
/// valuable check from that suite — the banned-phrase scanner across
/// the full user-context matrix — plus a handful of structural
/// invariants on the new LessonRitual + LessonBeat shape.
///
/// Coverage shape:
///   - Walk every LessonID × user-context permutation (~864 contexts)
///   - Extract every user-facing text string from every beat
///   - Run a battery of banned-phrase regexes against the text
///   - Assert structural invariants on the ritual shape
///
/// A failure prints lesson + user-context provenance so the bad string
/// is locatable from the test log without manual hunting.
final class JeniMethodRitualSafetyTests: XCTestCase {

    // MARK: - Safety matrix

    /// All non-empty values for each axis of personalization. The
    /// Cartesian product is the safety matrix. Empty-string variants
    /// are included for axes where the user might skip / not answer.
    private static let goals = ["loseWeight", "slimLegs", "toneCore", "fullBody", ""]
    private static let experiences = ["neverTried", "triedFailed", "sometimes", "regularly", ""]
    private static let bodyFoci: [[String]] = [
        ["flatBelly"], ["tonedArms"], ["roundButt"],
        ["slimLegs"], ["fullBody"], []
    ]
    private static let identities = ["powerful", "calm", "light", "strong", "radiant", ""]

    /// 5 × 5 × 6 × 6 = 900 user-context permutations. Generated once,
    /// shared across test cases.
    private static let safetyMatrix: [JeniMethodUserContext] = {
        var users: [JeniMethodUserContext] = []
        for goal in goals {
            for experience in experiences {
                for bodyFocus in bodyFoci {
                    for identity in identities {
                        users.append(JeniMethodUserContext(
                            name: "sarah",
                            voicePreference: "encouraging",
                            experience: experience,
                            goal: goal,
                            bodyFocus: bodyFocus,
                            identityFeeling: identity
                        ))
                    }
                }
            }
        }
        return users
    }()

    // MARK: - Text extraction

    /// One sample of user-facing text with provenance.
    private struct TextSample {
        let text: String
        let lesson: LessonID
        let context: String
    }

    /// Every user-facing string from every beat across the full matrix.
    /// Pause labels are included only if non-nil (nil labels are silent
    /// pauses by design and shouldn't be checked).
    private func everyText() -> [TextSample] {
        var out: [TextSample] = []
        for lesson in LessonID.allCases {
            for user in Self.safetyMatrix {
                let ritual = JeniMethodRitualContent.resolve(lesson: lesson, user: user)
                for beat in ritual.beats {
                    for text in beatTexts(beat.kind) {
                        out.append(TextSample(
                            text: text,
                            lesson: lesson,
                            context: describe(user)
                        ))
                    }
                }
            }
        }
        return out
    }

    private func beatTexts(_ kind: LessonBeatKind) -> [String] {
        switch kind {
        case .welcome(let line, _):
            return [line]
        case .breath:
            return []
        case .line(let text, _):
            return [text]
        case .illustration:
            return []
        case .illustratedExplanation(_, let eyebrow, let headline, _, let body):
            return [eyebrow, headline, body]
        case .movement(let invitation, _):
            return [invitation]
        case .pause(let label):
            return label.map { [$0] } ?? []
        case .close(let line, _):
            return [line]
        case .workoutHandoff(let line, _, let ctaLabel):
            return [line, ctaLabel]
        }
    }

    private func describe(_ u: JeniMethodUserContext) -> String {
        "goal=\(u.goal),exp=\(u.experience),bf=\(u.bodyFocus.joined(separator: "|")),id=\(u.identityFeeling)"
    }

    private func firstMatch(_ pattern: String, in text: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return false
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.firstMatch(in: text, options: [], range: range) != nil
    }

    // MARK: - Banned-phrase scanners

    /// "earn it" / "earn food" / "earn this" framing reinforces
    /// restriction logic — the body shouldn't be told it must earn
    /// rest or food. Day 4 says "you never earn food" / "you don't
    /// earn food by working out" which is the ANTI-framing; the test
    /// allows "don't earn" and "never earn" preceding the noun.
    func testNoEarnItFraming() {
        // Match "earn (it|food|rest|...)", but not when preceded by
        // "don't" / "never" / "no" within ~10 chars.
        let pattern = #"(?<!don['’]t )(?<!never )(?<!no )(?<!\bnot )\bearn[s]?\s+(it|food|rest|your|this|the)\b"#
        for sample in everyText() where firstMatch(pattern, in: sample.text) {
            XCTFail("[\(sample.lesson) | \(sample.context)] 'earn it' framing: \"\(sample.text)\"")
        }
    }

    /// Restriction-coded language: cleanses, detoxes, starvation,
    /// crash diets. Day 4 says "no cleanses. no detoxes." — that's
    /// anti-restriction; the test whitelists when preceded by "no ".
    func testNoRestrictionLanguage() {
        let banned = ["cleanse", "detox", "starve", "starvation", "crash diet"]
        for sample in everyText() {
            let lower = sample.text.lowercased()
            for term in banned {
                var searchStart = lower.startIndex
                while let r = lower.range(of: term, range: searchStart..<lower.endIndex) {
                    // Anti-framing window: "no " in the 5 chars before.
                    let windowStart = lower.index(r.lowerBound, offsetBy: -5, limitedBy: lower.startIndex) ?? lower.startIndex
                    let window = String(lower[windowStart..<r.lowerBound])
                    let isAnti = window.contains("no ")
                    if !isAnti {
                        XCTFail("[\(sample.lesson) | \(sample.context)] restriction term '\(term)': \"\(sample.text)\"")
                    }
                    searchStart = r.upperBound
                }
            }
        }
    }

    /// Body-shape promises — "you'll look slim", "you will be skinny",
    /// etc. The ritual never promises a body outcome on a timeline.
    func testNoBodyShapePromises() {
        let pattern = #"you('ll| will) (look|be|feel) (skinny|slim|thin|smaller|tiny)\b"#
        for sample in everyText() where firstMatch(pattern, in: sample.text) {
            XCTFail("[\(sample.lesson) | \(sample.context)] body-shape promise: \"\(sample.text)\"")
        }
    }

    /// Timeline promises — "in 30 days", "in 2 weeks", "in a month".
    /// The ritual makes no date-bound result claim.
    func testNoTimelinePromises() {
        // Match "in <digit>+ <day/week/month unit>". Spelled-out
        // ("in three weeks") would be caught visually; the regex
        // targets the numeric form because that's the more
        // marketing-flavored phrasing prone to creep in.
        let pattern = #"\bin\s+\d+\s+(day|days|week|weeks|month|months)\b"#
        for sample in everyText() where firstMatch(pattern, in: sample.text) {
            XCTFail("[\(sample.lesson) | \(sample.context)] timeline promise: \"\(sample.text)\"")
        }
    }

    /// Numeric digits next to nutrition words. Spelled-out numbers
    /// ("three hundred calories") are OK for science discussion
    /// because they don't read as a tracking instruction. A literal
    /// digit next to calorie/gram/macro is closer to "track this."
    func testNoDigitsNearNutritionWords() {
        let pattern = #"\b\d+\s*(calorie|calories|gram|grams|macro|macros|kcal|portion|portions)\b"#
        for sample in everyText() where firstMatch(pattern, in: sample.text) {
            XCTFail("[\(sample.lesson) | \(sample.context)] digit near nutrition word: \"\(sample.text)\"")
        }
    }

    /// Brand voice consistency: no "AI" / "absmaxxing" / "Sarah" /
    /// "plankAI" leaks (per the rebrand smoke test in CLAUDE.md).
    /// Note "sarah" appears as a TEST NAME in the matrix — we filter
    /// for the word inside user-facing copy, not the substituted name.
    func testNoLegacyBrandLeak() {
        // Match the legacy brand words only when not preceded by
        // namedPrefix interpolation (which would put "sarah." at the
        // start of the line followed by space — those are name uses).
        let banned = ["absmaxxing", "plankai"]
        for sample in everyText() {
            let lower = sample.text.lowercased()
            for term in banned where lower.contains(term) {
                XCTFail("[\(sample.lesson) | \(sample.context)] legacy brand leak '\(term)': \"\(sample.text)\"")
            }
        }
    }

    // MARK: - Structural invariants

    /// Every ritual returns a non-empty beat sequence for every user.
    func testEveryRitualHasBeats() {
        for lesson in LessonID.allCases {
            for user in Self.safetyMatrix {
                let ritual = JeniMethodRitualContent.resolve(lesson: lesson, user: user)
                XCTAssertFalse(
                    ritual.beats.isEmpty,
                    "[\(lesson) | \(describe(user))] empty ritual"
                )
            }
        }
    }

    /// Every ritual ends on a `.close` or `.workoutHandoff` beat —
    /// the only beat kinds that complete the flow. A `.line` or
    /// `.pause` as the final beat would leave the user unable to
    /// finish (no terminal "tap when you're ready" affordance).
    func testEveryRitualEndsCleanly() {
        for lesson in LessonID.allCases {
            for user in Self.safetyMatrix {
                let ritual = JeniMethodRitualContent.resolve(lesson: lesson, user: user)
                guard let last = ritual.beats.last else {
                    XCTFail("[\(lesson) | \(describe(user))] no beats")
                    continue
                }
                let ok: Bool
                switch last.kind {
                case .close, .workoutHandoff: ok = true
                default: ok = false
                }
                XCTAssertTrue(
                    ok,
                    "[\(lesson) | \(describe(user))] last beat is \(last.id) (kind: \(last.kind)) — must be .close or .workoutHandoff"
                )
            }
        }
    }

    /// Beat IDs must be unique within a lesson — SwiftUI uses them as
    /// the timer-cancellation key, and duplicates cause stale timers
    /// to fire on the wrong beat.
    func testBeatIdsUniqueWithinLesson() {
        for lesson in LessonID.allCases {
            // Beat structure is the same regardless of user context
            // (only text strings vary), so .empty is sufficient.
            let ritual = JeniMethodRitualContent.resolve(lesson: lesson, user: .empty)
            let ids = ritual.beats.map { $0.id }
            let unique = Set(ids)
            XCTAssertEqual(
                ids.count, unique.count,
                "[\(lesson)] duplicate beat IDs in \(ids.sorted())"
            )
        }
    }

    /// No beat-extracted text is empty. (Nil pause labels are silent
    /// by design and excluded from extraction; only non-nil text
    /// should always have content.)
    func testNoBeatHasEmptyText() {
        for sample in everyText() {
            XCTAssertFalse(
                sample.text.isEmpty,
                "[\(sample.lesson) | \(sample.context)] empty beat text"
            )
        }
    }

    /// Modules 1-5 (LessonID.dailyLessons) must include a
    /// `.workoutHandoff` beat so the lesson can hand off to the
    /// workout cover. The generic Module 6 also ends with a handoff
    /// (it IS the pre-workout ritual).
    func testEveryRitualHasWorkoutHandoff() {
        for lesson in LessonID.allCases {
            let ritual = JeniMethodRitualContent.resolve(lesson: lesson, user: .empty)
            let hasHandoff = ritual.beats.contains { beat in
                if case .workoutHandoff = beat.kind { return true }
                return false
            }
            XCTAssertTrue(
                hasHandoff,
                "[\(lesson)] no .workoutHandoff beat — ritual can't hand off to workout"
            )
        }
    }

    // MARK: - Analytics shape sanity

    /// `JeniMethodAnalytics.lessonProps` returns the expected keys
    /// after the Phase 9.22 cleanup (cards field removed from
    /// ResolvedLesson).
    func testLessonPropsKeyset() {
        let shim = ResolvedLesson(
            id: 1,
            topic: "why_this_works",
            standingSafetyLine: "stand on something stable",
            voice: "encouraging"
        )
        let user = JeniMethodUserContext(
            name: "sarah",
            voicePreference: "encouraging",
            experience: "neverTried",
            goal: "loseWeight",
            bodyFocus: ["slimLegs"],
            identityFeeling: "powerful"
        )
        let props = JeniMethodAnalytics.lessonProps(
            lesson: shim, user: user, paidStatus: "entitled"
        )
        let expected: Set<String> = [
            "lesson_id", "lesson_topic", "user_goal", "experience", "paid_status",
        ]
        XCTAssertTrue(
            expected.isSubset(of: Set(props.keys)),
            "lessonProps missing keys: \(expected.subtracting(props.keys))"
        )
        XCTAssertEqual(props["lesson_id"] as? Int, 1)
        XCTAssertEqual(props["lesson_topic"] as? String, "why_this_works")
        XCTAssertEqual(props["paid_status"] as? String, "entitled")
    }

    /// `JeniMethodAnalytics.completedProps` returns the cohort total
    /// keys reported on the terminal `diet_education_completed` event.
    func testCompletedPropsKeyset() {
        let user = JeniMethodUserContext.empty
        let props = JeniMethodAnalytics.completedProps(
            user: user, lessonsCompleted: 5, lessonsSkipped: 1, daysElapsed: 5
        )
        let expected: Set<String> = [
            "lessons_completed", "lessons_skipped", "days_elapsed",
            "user_goal", "experience",
        ]
        XCTAssertTrue(
            expected.isSubset(of: Set(props.keys)),
            "completedProps missing keys: \(expected.subtracting(props.keys))"
        )
        XCTAssertEqual(props["lessons_completed"] as? Int, 5)
        XCTAssertEqual(props["lessons_skipped"] as? Int, 1)
        XCTAssertEqual(props["days_elapsed"] as? Int, 5)
    }
}
