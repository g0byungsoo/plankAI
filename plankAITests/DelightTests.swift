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
        XCTAssertTrue(a.text.hasPrefix("your record starts here."), a.text)
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
        XCTAssertTrue(a.text.contains("floor covered"), a.text)
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
