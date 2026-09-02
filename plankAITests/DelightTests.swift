import XCTest
@testable import plankAI

// MARK: - DelightTests (p64 — THE DELIGHT LAYER)
//
// The celebration system's domain rules, pinned:
//   · CelebrationLedger — a celebration corresponds to a meaningful
//     event, once per day; undo/redo answers quietly.
//   · BeatCompletion — one authority for "does this beat render as
//     done", covering the offered rows the founder walk caught
//     rendering nothing (water marked → byte-identical row; step
//     goal crossed → still an invitation).
//   · PlateAnswerEngine first-of-day — the day's first plate leads
//     the answer, outranked by the record's first plate ever, safe
//     under suppression, and never a second time in one day (words
//     repeat with the fact; the CELEBRATION is what the ledger
//     rations).

final class DelightTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suiteName = "delight-tests-\(UUID().uuidString)"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    // MARK: - CelebrationLedger

    func testFreshDayCelebrates() {
        XCTAssertTrue(CelebrationLedger.shouldCelebrate(
            .waterDone, dayKey: "2026-09-01", defaults: defaults
        ))
    }

    func testSameDayRepeatIsQuiet() {
        CelebrationLedger.recordCelebrated(
            .waterDone, dayKey: "2026-09-01", defaults: defaults
        )
        XCTAssertFalse(CelebrationLedger.shouldCelebrate(
            .waterDone, dayKey: "2026-09-01", defaults: defaults
        ))
    }

    func testNextDayCelebratesAgain() {
        CelebrationLedger.recordCelebrated(
            .waterDone, dayKey: "2026-09-01", defaults: defaults
        )
        XCTAssertTrue(CelebrationLedger.shouldCelebrate(
            .waterDone, dayKey: "2026-09-02", defaults: defaults
        ))
    }

    /// Adversarial: unmark then re-mark inside one day — the second
    /// completion settles, it does not burst again.
    func testUnmarkRemarkSameDayStaysQuiet() {
        // mark (celebrates, latches)
        XCTAssertTrue(CelebrationLedger.shouldCelebrate(
            .waterDone, dayKey: "2026-09-01", defaults: defaults
        ))
        CelebrationLedger.recordCelebrated(
            .waterDone, dayKey: "2026-09-01", defaults: defaults
        )
        // unmark, then mark again the same day
        XCTAssertFalse(CelebrationLedger.shouldCelebrate(
            .waterDone, dayKey: "2026-09-01", defaults: defaults
        ))
    }

    func testMomentsLatchIndependently() {
        CelebrationLedger.recordCelebrated(
            .waterDone, dayKey: "2026-09-01", defaults: defaults
        )
        XCTAssertTrue(CelebrationLedger.shouldCelebrate(
            .firstPlateToday, dayKey: "2026-09-01", defaults: defaults
        ))
    }

    /// The §38 contract: every latch lives under the swept prefix,
    /// so account B's first spark is never eaten by account A's.
    func testLedgerKeysCarryTheSweepPrefix() {
        for moment in CelebrationMoment.allCases {
            XCTAssertTrue(
                CelebrationLedger.key(moment).hasPrefix("celebration."),
                "\(moment) key escapes the sign-out sweep"
            )
        }
    }

    // MARK: - BeatCompletion (the offered rows tell the truth)

    func testWaterCompleteRendersDone() {
        let s = BeatCompletion.state(
            for: .water(ml: nil),
            checkStates: ["water": "complete"],
            stepsToday: 0
        )
        XCTAssertTrue(s.isDone)
        XCTAssertFalse(s.isAuto)
    }

    func testWaterEmptyRendersOpen() {
        let s = BeatCompletion.state(
            for: .water(ml: nil),
            checkStates: [:],
            stepsToday: 0
        )
        XCTAssertFalse(s.isDone)
    }

    func testStepsAtGoalRendersDone() {
        let s = BeatCompletion.state(
            for: .steps(goal: 7_500),
            checkStates: [:],
            stepsToday: 7_500
        )
        XCTAssertTrue(s.isDone)
        XCTAssertTrue(s.isAuto)
        XCTAssertEqual(s.progress, 1)
    }

    func testStepsUnderGoalRendersProgress() {
        let s = BeatCompletion.state(
            for: .steps(goal: 8_000),
            checkStates: [:],
            stepsToday: 2_000
        )
        XCTAssertFalse(s.isDone)
        XCTAssertEqual(s.progress ?? 0, 0.25, accuracy: 0.001)
    }

    // p65 — THE FOUNDER'S SECOND WALK: "I can manually complete the
    // step/walking action and it does not visibly become checked."
    // The walking ask's quick-mark and the mark sheet both write
    // `steps → complete`, the record persists and syncs, the day
    // count reads "2 of 2" — and the row renders its open circle
    // forever, because the steps branch consulted ONLY the live
    // count. Her word must complete the ACTION; the sensor keeps
    // owning the NUMBER (a manual mark never invents a step count).

    func testStepsManualMarkRendersDone() {
        let s = BeatCompletion.state(
            for: .steps(goal: 7_500),
            checkStates: ["steps": "complete"],
            stepsToday: 6_400
        )
        XCTAssertTrue(s.isDone, "her explicit mark must render as done")
        XCTAssertFalse(s.isAuto, "a manual mark is her word, not the sensor's")
    }

    func testStepsMeasuredCrossingOutranksManualMark() {
        let s = BeatCompletion.state(
            for: .steps(goal: 7_500),
            checkStates: ["steps": "complete"],
            stepsToday: 9_214
        )
        XCTAssertTrue(s.isDone)
        XCTAssertTrue(s.isAuto, "a crossed goal is the measured fact")
    }

    /// An `autoCompleted` record with the live count below the goal
    /// (stale record, fresh sensors) must NOT fake a crossing — the
    /// measurement stays the authority for the auto path.
    func testStaleAutoRecordNeverFakesACrossing() {
        let s = BeatCompletion.state(
            for: .steps(goal: 7_500),
            checkStates: ["steps": "autoCompleted"],
            stepsToday: 100
        )
        XCTAssertFalse(s.isDone)
    }

    func testStepsManualUnmarkReopens() {
        let s = BeatCompletion.state(
            for: .steps(goal: 7_500),
            checkStates: ["steps": "empty"],
            stepsToday: 6_400
        )
        XCTAssertFalse(s.isDone)
    }

    // The row's title speaks the same authority: a measured crossing
    // states the count; her word states the act, never a numeral it
    // did not measure.

    func testStepsTitleMeasuredStatesTheCount() {
        let s = JKBeatState(isDone: true, isAuto: true, progress: 1)
        XCTAssertEqual(
            BeatCompletion.stepsRowTitle(
                state: s, todayCount: 9_214, goalTitle: "7,500 steps"
            ),
            "9,214 steps"
        )
    }

    func testStepsTitleManualNeverInventsANumber() {
        let s = JKBeatState(isDone: true, isAuto: false, progress: nil)
        let title = BeatCompletion.stepsRowTitle(
            state: s, todayCount: 6_400, goalTitle: "7,500 steps"
        )
        XCTAssertNil(
            title.rangeOfCharacter(from: .decimalDigits),
            "her word carries no numeral: \(title)"
        )
    }

    func testStepsTitleOpenKeepsTheAsk() {
        let s = JKBeatState(isDone: false, isAuto: true, progress: 0.85)
        XCTAssertEqual(
            BeatCompletion.stepsRowTitle(
                state: s, todayCount: 6_400, goalTitle: "7,500 steps"
            ),
            "7,500 steps"
        )
    }

    // p65 — DUPLICATE CHECK ROWS MUST NEVER CRASH. Found live: two
    // rows for one (plan, day, itemKey) — one minted locally, one
    // arriving from the insert-only hydrate under its own id (the
    // exact shape two devices produce for any slot both marked) —
    // and `Dictionary(uniqueKeysWithValues:)` asserted, crashing the
    // app at EVERY subsequent snapshot. The fold merges: a resolved
    // state outranks empty; ties go to the newest write.

    func testDuplicateCheckRowsMergeInsteadOfCrashing() {
        let states = BeatCompletion.checkStates(from: [
            (key: "steps", state: "complete", updatedAt: Date(timeIntervalSince1970: 100)),
            (key: "steps", state: "complete", updatedAt: Date(timeIntervalSince1970: 200)),
        ])
        XCTAssertEqual(states["steps"], "complete")
    }

    func testResolvedStateOutranksEmptyAcrossDuplicates() {
        // Device A unmarked (empty, newer); device B's completed row
        // hydrated in (older). Her completion survives the merge —
        // losing a mark to a stale duplicate would re-open a done day.
        let states = BeatCompletion.checkStates(from: [
            (key: "water", state: "empty", updatedAt: Date(timeIntervalSince1970: 300)),
            (key: "water", state: "complete", updatedAt: Date(timeIntervalSince1970: 100)),
        ])
        XCTAssertEqual(states["water"], "complete")
    }

    func testDuplicateResolvedStatesNewestWins() {
        let states = BeatCompletion.checkStates(from: [
            (key: "steps", state: "autoCompleted", updatedAt: Date(timeIntervalSince1970: 100)),
            (key: "steps", state: "complete", updatedAt: Date(timeIntervalSince1970: 200)),
        ])
        XCTAssertEqual(states["steps"], "complete")
    }

    func testDistinctKeysAllSurviveTheFold() {
        let states = BeatCompletion.checkStates(from: [
            (key: "steps", state: "complete", updatedAt: .distantPast),
            (key: "water", state: "empty", updatedAt: .distantPast),
            (key: "snap_meal", state: "autoCompleted", updatedAt: .distantPast),
        ])
        XCTAssertEqual(states.count, 3)
        XCTAssertEqual(states["water"], "empty")
    }

    /// v24's rule, carried through the extraction: a SKIPPED dose is
    /// resolved, not open.
    func testMedicationSkippedRendersResolved() {
        let s = BeatCompletion.state(
            for: .medication,
            checkStates: ["medication": "skipped"],
            stepsToday: 0
        )
        XCTAssertTrue(s.isDone)
    }

    func testAutoCompletedReadsAuto() {
        let s = BeatCompletion.state(
            for: .snapMeal,
            checkStates: ["snap_meal": "autoCompleted"],
            stepsToday: 0
        )
        XCTAssertTrue(s.isDone)
        XCTAssertTrue(s.isAuto)
    }

    // MARK: - PlateAnswerEngine: the day's first plate

    private typealias E = PlateAnswerEngine
    private typealias I = PlateAnswerEngine.Input

    func testFirstPlateOfDayLeadsTheAnswer() {
        let a = E.afterPlate(I(
            proteinOnFileG: 0, plateProteinG: 32, proteinFloorG: 120,
            platesOnFile: 0
        ))
        XCTAssertTrue(a.firstPlateOfDay)
        XCTAssertTrue(a.text.hasPrefix("today's first plate."), a.text)
        XCTAssertTrue(a.text.contains("32 of 120 g"), a.text)
    }

    func testSecondPlateOfDayDoesNotClaimFirst() {
        let a = E.afterPlate(I(
            proteinOnFileG: 32, plateProteinG: 20, proteinFloorG: 120,
            platesOnFile: 1
        ))
        XCTAssertFalse(a.firstPlateOfDay)
        XCTAssertFalse(a.text.contains("first plate"), a.text)
    }

    func testFirstEverOutranksFirstOfDay() {
        let a = E.afterPlate(I(
            proteinOnFileG: 0, plateProteinG: 30, proteinFloorG: 120,
            platesOnFile: 0, isFirstPlateEver: true
        ))
        XCTAssertFalse(a.firstPlateOfDay)
        XCTAssertTrue(a.text.hasPrefix("nice. your first plate, logged."), a.text)
    }

    func testFirstOfDaySuppressedKeepsSentenceNoNumerals() {
        let a = E.afterPlate(I(
            proteinOnFileG: 0, plateProteinG: 32, proteinFloorG: 120,
            platesOnFile: 0, numericsSuppressed: true
        ))
        XCTAssertTrue(a.firstPlateOfDay)
        XCTAssertTrue(a.text.hasPrefix("today's first plate."), a.text)
        XCTAssertNil(
            a.text.rangeOfCharacter(from: .decimalDigits),
            "a suppressed cohort never sees a numeral: \(a.text)"
        )
    }

    func testFirstOfDayZeroProteinPlateNeverRendersZero() {
        let a = E.afterPlate(I(
            proteinOnFileG: 0, plateProteinG: 0, proteinFloorG: 120,
            platesOnFile: 0
        ))
        XCTAssertTrue(a.firstPlateOfDay)
        XCTAssertTrue(a.text.hasPrefix("today's first plate."), a.text)
        XCTAssertFalse(a.text.contains("0 g"), a.text)
    }

    /// A first plate that also crosses the floor: the crossing (the
    /// day's peak) outranks the spark — one celebration per commit.
    func testFirstOfDayCrossingMarksTheCrest() {
        let a = E.afterPlate(I(
            proteinOnFileG: 0, plateProteinG: 130, proteinFloorG: 120,
            platesOnFile: 0
        ))
        XCTAssertTrue(a.floorCrossed)
        XCTAssertTrue(a.firstPlateOfDay)
        XCTAssertTrue(a.text.hasPrefix("today's first plate."), a.text)
        XCTAssertTrue(a.text.contains("goal hit"), a.text)
    }

    /// The refusal set holds on the new branch too.
    func testFirstOfDayCarriesNoBannedWord() {
        for plate in [0, 1, 40, 200] {
            for floor in [nil, 0, 120] as [Int?] {
                for suppressed in [false, true] {
                    let a = E.afterPlate(I(
                        proteinOnFileG: 0, plateProteinG: plate,
                        proteinFloorG: floor, platesOnFile: 0,
                        numericsSuppressed: suppressed
                    ))
                    for banned in E.bannedWords {
                        XCTAssertFalse(
                            Self.containsWord(banned, in: a.text),
                            "'\(banned)' in: \(a.text)"
                        )
                    }
                    XCTAssertEqual(a.text, a.text.lowercased())
                    XCTAssertTrue(
                        a.punch.isEmpty || a.text.contains(a.punch)
                    )
                }
            }
        }
    }

    // MARK: - PlateMomentClaim (p65 — ONE full-page moment per commit)

    func testFirstEverClaimsTheMomentPage() {
        let a = E.afterPlate(I(
            proteinOnFileG: 0, plateProteinG: 130, proteinFloorG: 120,
            platesOnFile: 0, isFirstPlateEver: true
        ))
        let m = PlateMomentClaim.claim(
            answer: a, isFirstEver: true,
            dayKey: "2026-09-01", defaults: defaults
        )
        XCTAssertEqual(m?.tier, "moment")
        XCTAssertEqual(m?.headline, "nice. your first plate, logged.")
        // The page's fact is the engine's own sentence minus the lead
        // the headline already speaks — one sentence authority.
        XCTAssertEqual(m?.fact, "130 of 120 g, goal hit.")
        XCTAssertEqual(m?.occasion, "first_plate_ever")
    }

    /// Adversarial (founder: no duplicate celebration): delete every
    /// plate ever, log again — the sentence repeats, the PAGE does
    /// not. The lifetime latch holds; the commit falls through to the
    /// day's own facts.
    func testFirstEverIsOncePerLifetime() {
        let a = E.afterPlate(I(
            proteinOnFileG: 0, plateProteinG: 30, proteinFloorG: 120,
            platesOnFile: 0, isFirstPlateEver: true
        ))
        XCTAssertEqual(PlateMomentClaim.claim(
            answer: a, isFirstEver: true,
            dayKey: "2026-09-01", defaults: defaults
        )?.tier, "moment")
        // Wiped record, same account: first-ever again by derivation,
        // same answer shape — but the latch says the page already
        // played. The commit settles with the sentence alone (the
        // engine's "nice. your first plate, logged." text still
        // speaks; a fact repeats, a celebration does not).
        XCTAssertNil(PlateMomentClaim.claim(
            answer: a, isFirstEver: true,
            dayKey: "2026-09-01", defaults: defaults
        ))
    }

    func testCrossingOutranksTheFirstPlateSpark() {
        let a = E.afterPlate(I(
            proteinOnFileG: 0, plateProteinG: 130, proteinFloorG: 120,
            platesOnFile: 0
        ))
        let m = PlateMomentClaim.claim(
            answer: a, isFirstEver: false,
            dayKey: "2026-09-01", defaults: defaults
        )
        XCTAssertEqual(m?.tier, "crest")
        XCTAssertEqual(m?.headline, "you hit your protein goal.")
        // A first plate that crosses carries BOTH facts on one page —
        // never two stacked celebrations (ONE coherent moment).
        XCTAssertEqual(m?.fact, "today's first plate. 130 of 120 g. nice work.")
        // The spark was NOT spent by the crest — but the day's first
        // plate has now happened, so a later plate is not "first".
        XCTAssertTrue(CelebrationLedger.shouldCelebrate(
            .firstPlateToday, dayKey: "2026-09-01", defaults: defaults
        ))
    }

    /// p68 — an ordinary (non-first) crossing states the DAY in one
    /// clause; the plate's own grams stay on the result page.
    func testOrdinaryCrossingCrestStatesTheDay() {
        let a = E.afterPlate(I(
            proteinOnFileG: 99, plateProteinG: 23, proteinFloorG: 120,
            platesOnFile: 2
        ))
        let m = PlateMomentClaim.claim(
            answer: a, isFirstEver: false,
            dayKey: "2026-09-01", defaults: defaults
        )
        XCTAssertEqual(m?.tier, "crest")
        XCTAssertEqual(m?.headline, "you hit your protein goal.")
        XCTAssertEqual(m?.fact, "122 of 120 g today. nice work.")
    }

    func testFirstPlateTodayClaimsThePageOnce() {
        let a = E.afterPlate(I(
            proteinOnFileG: 0, plateProteinG: 32, proteinFloorG: 120,
            platesOnFile: 0
        ))
        let m = PlateMomentClaim.claim(
            answer: a, isFirstEver: false,
            dayKey: "2026-09-01", defaults: defaults
        )
        XCTAssertEqual(m?.tier, "spark")
        XCTAssertEqual(m?.headline, "today's first plate.")
        XCTAssertEqual(m?.fact, "32 of 120 g of protein.")
        // Adversarial: delete every plate, log again the same day —
        // the sentence repeats (a fact), the page does not.
        XCTAssertNil(PlateMomentClaim.claim(
            answer: a, isFirstEver: false,
            dayKey: "2026-09-01", defaults: defaults
        ))
        // A fresh day earns its first-plate moment again.
        XCTAssertEqual(PlateMomentClaim.claim(
            answer: a, isFirstEver: false,
            dayKey: "2026-09-02", defaults: defaults
        )?.tier, "spark")
    }

    func testAnOrdinaryLaterPlateClaimsNothing() {
        let a = E.afterPlate(I(
            proteinOnFileG: 40, plateProteinG: 20, proteinFloorG: 120,
            platesOnFile: 2
        ))
        XCTAssertNil(PlateMomentClaim.claim(
            answer: a, isFirstEver: false,
            dayKey: "2026-09-01", defaults: defaults
        ))
    }

    /// The suppressed cohort's first plate still gets its moment —
    /// with a numeral-free page (the engine's own sentence).
    func testSuppressedFirstPlatePageCarriesNoNumeral() {
        let a = E.afterPlate(I(
            proteinOnFileG: 0, plateProteinG: 32, proteinFloorG: 120,
            platesOnFile: 0, numericsSuppressed: true
        ))
        let m = PlateMomentClaim.claim(
            answer: a, isFirstEver: false,
            dayKey: "2026-09-01", defaults: defaults
        )
        XCTAssertEqual(m?.tier, "spark")
        for line in [m?.headline, m?.fact].compactMap({ $0 }) {
            XCTAssertNil(
                line.rangeOfCharacter(from: .decimalDigits),
                "a suppressed cohort never sees a numeral: \(line)"
            )
        }
    }

    /// A first plate whose sentence is ONLY the lead ships a nil fact
    /// (nothing to repeat), and a zero-protein plate never prints 0.
    func testMomentFactNeverRendersZeroOrEmpty() {
        let a = E.afterPlate(I(
            proteinOnFileG: 0, plateProteinG: 0, proteinFloorG: 120,
            platesOnFile: 0
        ))
        let m = PlateMomentClaim.claim(
            answer: a, isFirstEver: false,
            dayKey: "2026-09-01", defaults: defaults
        )
        XCTAssertFalse(m?.fact?.contains("0 g") ?? false)
        XCTAssertNotEqual(m?.fact, "")
    }

    /// Every page headline obeys the engine's own refusal set.
    func testMomentHeadlinesCarryNoBannedWord() {
        let answers: [(PlateAnswerEngine.Answer, Bool)] = [
            (E.afterPlate(I(proteinOnFileG: 0, plateProteinG: 30,
                            proteinFloorG: 120, platesOnFile: 0,
                            isFirstPlateEver: true)), true),
            (E.afterPlate(I(proteinOnFileG: 100, plateProteinG: 30,
                            proteinFloorG: 120, platesOnFile: 2)), false),
            (E.afterPlate(I(proteinOnFileG: 0, plateProteinG: 30,
                            proteinFloorG: 120, platesOnFile: 0)), false),
        ]
        for (a, ever) in answers {
            guard let m = PlateMomentClaim.claim(
                answer: a, isFirstEver: ever,
                dayKey: "2026-09-01", defaults: defaults
            ) else { continue }
            for line in [m.headline, m.fact ?? "", m.eyebrow ?? "", m.cta] {
                for banned in E.bannedWords {
                    XCTAssertFalse(
                        Self.containsWord(banned, in: line),
                        "'\(banned)' in: \(line)"
                    )
                }
                XCTAssertEqual(line, line.lowercased())
            }
            XCTAssertTrue(m.punch.isEmpty || m.headline.contains(m.punch))
        }
    }

    /// The house banned-word rule: WORD boundaries, not substrings
    /// (naive `contains` reports "over" inside "covered" — the
    /// PlateAnswerEngineTests convention, mirrored).
    private static func containsWord(_ needle: String, in text: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: needle)
        let pattern = needle.rangeOfCharacter(from: .letters) == nil
            ? escaped
            : #"(?<![a-z])"# + escaped + #"(?![a-z])"#
        return text.lowercased().range(of: pattern, options: .regularExpression) != nil
    }
}
