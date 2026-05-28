import XCTest
@testable import plankAI

/// Phase 10 — safety + structural test suite for the primer-style lesson
/// model (LessonScript / LessonPage). Replaces the beat-engine suite. The
/// most valuable check carries over: the banned-phrase scanner across the
/// full user-context matrix, plus structural invariants on the new page
/// shape.
///
/// Coverage shape:
///   - Walk every LessonID × user-context permutation (~900 contexts)
///   - Extract every user-facing string from every page
///   - Run a battery of banned-phrase regexes against the text
///   - Assert structural invariants on the LessonScript + LessonPage shape
///
/// A failure prints lesson + user-context provenance so the bad string
/// is locatable from the test log without manual hunting.
final class JeniMethodRitualSafetyTests: XCTestCase {

    // MARK: - Safety matrix

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

    private struct TextSample {
        let text: String
        let lesson: LessonID
        let context: String
    }

    /// Every user-facing string from every page across the full matrix.
    private func everyText() -> [TextSample] {
        var out: [TextSample] = []
        for lesson in LessonID.allCases {
            for user in Self.safetyMatrix {
                let script = JeniMethodRitualContent.resolve(lesson: lesson, user: user)
                for page in script.pages {
                    for text in pageTexts(page) {
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

    /// All user-facing strings on a page (skips nil optionals).
    private func pageTexts(_ page: LessonPage) -> [String] {
        var texts: [String] = [page.headline, page.ctaLabel]
        if let eyebrow = page.eyebrow { texts.append(eyebrow) }
        if let body = page.body { texts.append(body) }
        if let citation = page.citation { texts.append(citation) }
        if let breathLine = page.breathLine { texts.append(breathLine) }
        return texts
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

    /// "earn it" / "earn food" / "earn this" framing reinforces restriction
    /// logic. Day 10 says "you never earn food" which is the ANTI-framing;
    /// the test allows "don't earn" / "never earn" / "no earn" / "not earn".
    func testNoEarnItFraming() {
        let pattern = #"(?<!don['’]t )(?<!never )(?<!no )(?<!\bnot )\bearn[s]?\s+(it|food|rest|your|this|the)\b"#
        for sample in everyText() where firstMatch(pattern, in: sample.text) {
            XCTFail("[\(sample.lesson) | \(sample.context)] 'earn it' framing: \"\(sample.text)\"")
        }
    }

    /// Restriction-coded language: cleanses, detoxes, starvation, crash
    /// diets — whitelisted only when preceded by "no ".
    func testNoRestrictionLanguage() {
        let banned = ["cleanse", "detox", "starve", "starvation", "crash diet"]
        for sample in everyText() {
            let lower = sample.text.lowercased()
            for term in banned {
                var searchStart = lower.startIndex
                while let r = lower.range(of: term, range: searchStart..<lower.endIndex) {
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

    /// Body-shape promises — "you'll look slim", "you will be skinny", etc.
    func testNoBodyShapePromises() {
        let pattern = #"you('ll| will) (look|be|feel) (skinny|slim|thin|smaller|tiny)\b"#
        for sample in everyText() where firstMatch(pattern, in: sample.text) {
            XCTFail("[\(sample.lesson) | \(sample.context)] body-shape promise: \"\(sample.text)\"")
        }
    }

    /// Timeline promises — "in 30 days", "in 2 weeks". Numeric form only;
    /// spelled-out ("sixty-six days") reads as science, not a result clock.
    func testNoTimelinePromises() {
        let pattern = #"\bin\s+\d+\s+(day|days|week|weeks|month|months)\b"#
        for sample in everyText() where firstMatch(pattern, in: sample.text) {
            XCTFail("[\(sample.lesson) | \(sample.context)] timeline promise: \"\(sample.text)\"")
        }
    }

    /// Numeric digits next to nutrition words. Spelled-out numbers are OK
    /// (science framing); a literal digit next to calorie/gram/portion is
    /// closer to "track this."
    func testNoDigitsNearNutritionWords() {
        let pattern = #"\b\d+\s*(calorie|calories|gram|grams|macro|macros|kcal|portion|portions)\b"#
        for sample in everyText() where firstMatch(pattern, in: sample.text) {
            XCTFail("[\(sample.lesson) | \(sample.context)] digit near nutrition word: \"\(sample.text)\"")
        }
    }

    /// Brand voice consistency: no legacy brand leaks.
    func testNoLegacyBrandLeak() {
        let banned = ["absmaxxing", "plankai"]
        for sample in everyText() {
            let lower = sample.text.lowercased()
            for term in banned where lower.contains(term) {
                XCTFail("[\(sample.lesson) | \(sample.context)] legacy brand leak '\(term)': \"\(sample.text)\"")
            }
        }
    }

    // MARK: - Structural invariants

    /// Every lesson returns a non-empty page sequence for every user.
    func testEveryLessonHasPages() {
        for lesson in LessonID.allCases {
            for user in Self.safetyMatrix {
                let script = JeniMethodRitualContent.resolve(lesson: lesson, user: user)
                XCTAssertFalse(
                    script.pages.isEmpty,
                    "[\(lesson) | \(describe(user))] empty lesson"
                )
            }
        }
    }

    /// Every lesson ends on an `isHandoff` page — the only page whose CTA
    /// completes the lesson and launches the workout. A non-handoff final
    /// page would leave the user with a dead-end "continue."
    func testEveryLessonEndsWithHandoff() {
        for lesson in LessonID.allCases {
            for user in Self.safetyMatrix {
                let script = JeniMethodRitualContent.resolve(lesson: lesson, user: user)
                guard let last = script.pages.last else {
                    XCTFail("[\(lesson) | \(describe(user))] no pages")
                    continue
                }
                XCTAssertTrue(
                    last.isHandoff,
                    "[\(lesson) | \(describe(user))] last page '\(last.id)' is not a handoff"
                )
            }
        }
    }

    /// Exactly the final page is a handoff — no earlier page should claim
    /// the workout-launch CTA (would let the user skip the rest).
    func testOnlyFinalPageIsHandoff() {
        for lesson in LessonID.allCases {
            let script = JeniMethodRitualContent.resolve(lesson: lesson, user: .empty)
            let handoffCount = script.pages.filter { $0.isHandoff }.count
            XCTAssertEqual(
                handoffCount, 1,
                "[\(lesson)] expected exactly 1 handoff page, found \(handoffCount)"
            )
            XCTAssertTrue(
                script.pages.last?.isHandoff == true,
                "[\(lesson)] handoff page is not last"
            )
        }
    }

    /// Page IDs must be unique within a lesson.
    func testPageIdsUniqueWithinLesson() {
        for lesson in LessonID.allCases {
            let script = JeniMethodRitualContent.resolve(lesson: lesson, user: .empty)
            let ids = script.pages.map { $0.id }
            XCTAssertEqual(
                ids.count, Set(ids).count,
                "[\(lesson)] duplicate page IDs in \(ids.sorted())"
            )
        }
    }

    /// No extracted user-facing text is empty.
    func testNoPageHasEmptyText() {
        for sample in everyText() {
            XCTAssertFalse(
                sample.text.isEmpty,
                "[\(sample.lesson) | \(sample.context)] empty page text"
            )
        }
    }

    // MARK: - Analytics shape sanity

    /// `JeniMethodAnalytics.lessonProps` returns the expected keys.
    func testLessonPropsKeyset() {
        let shim = ResolvedLesson(
            id: 1,
            topic: "muscle_changes_the_math",
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
        XCTAssertEqual(props["lesson_topic"] as? String, "muscle_changes_the_math")
        XCTAssertEqual(props["paid_status"] as? String, "entitled")
    }

    /// `JeniMethodAnalytics.completedProps` returns the cohort total keys.
    func testCompletedPropsKeyset() {
        let user = JeniMethodUserContext.empty
        let props = JeniMethodAnalytics.completedProps(
            user: user, lessonsCompleted: 14, lessonsSkipped: 1, daysElapsed: 14
        )
        let expected: Set<String> = [
            "lessons_completed", "lessons_skipped", "days_elapsed",
            "user_goal", "experience",
        ]
        XCTAssertTrue(
            expected.isSubset(of: Set(props.keys)),
            "completedProps missing keys: \(expected.subtracting(props.keys))"
        )
        XCTAssertEqual(props["lessons_completed"] as? Int, 14)
        XCTAssertEqual(props["lessons_skipped"] as? Int, 1)
        XCTAssertEqual(props["days_elapsed"] as? Int, 14)
    }
}
