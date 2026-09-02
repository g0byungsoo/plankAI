import XCTest
@testable import plankAI

// MARK: - MoveTests (v25 E8.1)
//
// The rules that decide whether a number in Move is honest:
//
//   · active energy is only ever MEASURED — Move never reconstructs it
//     from steps, which is what the sheet it replaces did
//   · an estimate needs a body weight, or there is no number
//   · an estimate is rounded to a precision the model actually has
//   · nothing Move says is arithmetic against food
//   · the strength count is a count, never a verdict

final class MoveTests: XCTestCase {

    // MARK: - Estimated energy

    func testNoWeightMeansNoEstimate() {
        XCTAssertNil(MoveEnergy.estimatedKcal(kind: .walk, minutes: 30, weightKg: nil))
        XCTAssertNil(MoveEnergy.estimatedKcal(kind: .walk, minutes: 30, weightKg: 0))
        // A "weight" under 20 kg is a data-entry error, not a person the
        // model should scale to.
        XCTAssertNil(MoveEnergy.estimatedKcal(kind: .walk, minutes: 30, weightKg: 12))
    }

    func testNoMinutesMeansNoEstimate() {
        XCTAssertNil(MoveEnergy.estimatedKcal(kind: .cycle, minutes: 0, weightKg: 74))
    }

    func testEstimateIsRoundedToThePrecisionTheModelHas() {
        // MET × 3.5 × kg / 200 × min. 30 min walk at 74 kg:
        // 3.5 × 3.5 × 74 / 200 × 30 = 136.0 → 135 at 5-kcal resolution.
        let kcal = MoveEnergy.estimatedKcal(kind: .walk, minutes: 30, weightKg: 74)
        XCTAssertNotNil(kcal)
        XCTAssertEqual((kcal ?? 0) % 5, 0, "a MET model cannot resolve single kcal")
        XCTAssertEqual(kcal, 135)
    }

    /// An unknown activity must not be the most generous one, or "something
    /// else" becomes the option that inflates every estimate.
    func testUnknownActivityCarriesTheLowestMet() {
        let lowest = MoveEnergy.ManualKind.allCases.map(\.met).min()
        XCTAssertEqual(MoveEnergy.ManualKind.other.met, lowest)
    }

    func testEstimateScalesWithBodyMassAndDuration() {
        let small = MoveEnergy.estimatedKcal(kind: .cycle, minutes: 20, weightKg: 60) ?? 0
        let large = MoveEnergy.estimatedKcal(kind: .cycle, minutes: 20, weightKg: 100) ?? 0
        let longer = MoveEnergy.estimatedKcal(kind: .cycle, minutes: 60, weightKg: 60) ?? 0
        XCTAssertGreaterThan(large, small)
        XCTAssertGreaterThan(longer, small)
    }

    // MARK: - Provenance

    /// The rule the old steps sheet broke: it printed steps × weight × a
    /// constant as "energy" in the same typeface as everything else.
    /// Every value Move renders carries a provenance word, and there is no
    /// initialiser that produces one without.
    func testEveryProvenanceHasAWord() {
        for provenance in [MoveProvenance.measured, .entered, .estimated] {
            XCTAssertFalse(provenance.word.isEmpty)
            XCTAssertEqual(provenance.word, provenance.word.lowercased())
        }
        XCTAssertNotEqual(MoveProvenance.measured.word, MoveProvenance.estimated.word)
    }

    // MARK: - Strength, the one judgement

    func testOnlyTheThingThatLoadsMuscleCountsAsStrength() {
        let counting = MoveEnergy.ManualKind.allCases.filter(\.countsAsStrength)
        XCTAssertEqual(counting, [.strength],
                       "a generous definition here retires the only judgement Move makes")
    }

    func testStrengthCountsBothSensorAndSelfReport() {
        var record = emptyRecord()
        record.strengthSessionsLast7 = 1
        record.enteredSessionsLast7 = 1
        XCTAssertEqual(record.totalStrengthLast7, 2)
        XCTAssertTrue(record.strengthMet)
    }

    // MARK: - p63 · the record's receipt
    //
    // "record it" used to fire the record haptic and dismiss on the
    // same runloop — the strongest confirm in the grammar against a
    // vanishing sheet. The receipt answers the commit in words, from
    // facts already on hand, before the surface excuses itself.

    func testFirstHeavySessionReceiptStatesTheAsk() {
        let r = MoveEnergy.receipt(kind: .strength, strengthThisWeekBefore: 0)
        XCTAssertEqual(r.line, "logged")
        XCTAssertEqual(r.sub, "1 of 2 strength sessions this week. one more to go.")
    }

    func testSecondHeavySessionReceiptNamesTheAskMet() {
        let r = MoveEnergy.receipt(kind: .strength, strengthThisWeekBefore: 1)
        XCTAssertEqual(r.line, "that's twice this week")
        XCTAssertEqual(r.italic, ["twice"])
        XCTAssertEqual(r.sub, "nice work. that's what keeps muscle while the weight comes off.")
    }

    func testFurtherHeavySessionsCountPlainly() {
        let r = MoveEnergy.receipt(kind: .strength, strengthThisWeekBefore: 2)
        XCTAssertEqual(r.line, "done")
        XCTAssertEqual(r.sub, "3 strength sessions this week.")
    }

    func testNonStrengthReceiptNeverBorrowsTheStrengthAsk() {
        // A walk is counted, never graded against the strength target —
        // a generous receipt here would quietly retire the one
        // judgement Move makes (the countsAsStrength law).
        for kind in MoveEnergy.ManualKind.allCases where !kind.countsAsStrength {
            let r = MoveEnergy.receipt(kind: kind, strengthThisWeekBefore: 0)
            XCTAssertEqual(r.line, "logged")
            XCTAssertEqual(r.sub, "counted, alongside what health sees.")
            XCTAssertFalse(r.sub.contains("ask"))
        }
    }

    func testReceiptNeverGradesAndNeverShouts() {
        for kind in MoveEnergy.ManualKind.allCases {
            for before in 0...4 {
                let r = MoveEnergy.receipt(kind: kind, strengthThisWeekBefore: before)
                // p67 — the praise amendment: warm words ("nice") are
                // sanctioned for a real act (the twice-a-week receipt
                // carries one). Shame/hype words stay banned.
                for banned in ["awesome", "amazing",
                               "earn", "burn", "crush", "!"] {
                    XCTAssertFalse(r.line.lowercased().contains(banned), r.line)
                    XCTAssertFalse(r.sub.lowercased().contains(banned), r.sub)
                }
                XCTAssertEqual(r.line, r.line.lowercased(), r.line)
            }
        }
    }

    // MARK: - What next

    /// The whole product forbids movement-as-repayment. If this line ever
    /// contains the arithmetic, the feature has become a calorie chase.
    func testTheNextLineNeverMakesMovementRepaymentForFood() {
        var probes: [MoveRecord] = []
        var r = emptyRecord(); probes.append(r)
        r = emptyRecord(); r.strengthSessionsLast7 = 1; probes.append(r)
        r = emptyRecord(); r.strengthSessionsLast7 = 2; probes.append(r)
        r = emptyRecord(); r.strengthSessionsLast7 = 2
        r.stepsToday = 900; r.stepsBaseline = 8_000; probes.append(r)

        let banned = ["burn", "earn", "deficit", "work off", "off the", "cancel",
                      "make up for", "owe"]
        for probe in probes {
            guard let line = MoveEnergy.nextLine(probe) else { continue }
            XCTAssertEqual(line, line.lowercased(), line)
            for word in banned {
                XCTAssertFalse(line.contains(word), "'\(word)' in: \(line)")
            }
            XCTAssertFalse(line.contains("kcal"), line)
            XCTAssertFalse(line.contains("calorie"), line)
        }
    }

    /// An empty week is still stated, and still without a verdict — but
    /// it is the HEADLINE now, not a footnote under a 44pt zero. Move
    /// said "twice a week" in both places before, three inches apart.
    func testAnEmptyWeekIsStatedWithoutAVerdict() {
        guard case .nothingYet(let line) =
            MoveEnergy.strengthHeadline(emptyRecord())
        else { return XCTFail("an empty week must not render a numeral") }
        XCTAssertEqual(line, line.lowercased(), line)
        for word in ["failed", "missed", "should", "behind", "only", "0"] {
            XCTAssertFalse(line.contains(word), line)
        }
        // And it is said ONCE: the line below the record stands down.
        XCTAssertNil(
            MoveEnergy.nextLine(emptyRecord()),
            "the headline carries the zero; a second copy is the de-dup law broken"
        )
    }

    // MARK: - The headline

    /// A COUNT IS A HERO ONLY WHEN THERE IS SOMETHING TO COUNT. The
    /// denominator appears while the guidance is unmet and drops once it
    /// is met, and no state renders a zero numeral.
    func testTheHeadlineIsWordsAtZeroAndACountAfter() {
        XCTAssertEqual(
            MoveEnergy.strengthHeadline(emptyRecord()),
            .nothingYet("no strength sessions yet this week.")
        )

        var one = emptyRecord(); one.strengthSessionsLast7 = 1
        XCTAssertEqual(MoveEnergy.strengthHeadline(one), .count(done: 1, of: 2))

        var met = emptyRecord(); met.strengthSessionsLast7 = 2
        XCTAssertEqual(MoveEnergy.strengthHeadline(met), .count(done: 2, of: nil))

        // "3 of 2" reads as an error, not as three sessions.
        var over = emptyRecord(); over.strengthSessionsLast7 = 3
        XCTAssertEqual(MoveEnergy.strengthHeadline(over), .count(done: 3, of: nil))

        // Her own recorded sessions count toward the headline exactly
        // like HealthKit's.
        var entered = emptyRecord(); entered.enteredSessionsLast7 = 1
        XCTAssertEqual(MoveEnergy.strengthHeadline(entered), .count(done: 1, of: 2))
    }

    // MARK: - A zero-step day is an absence, not a reading

    /// `steps 0 · from health` dressed an absence in a sensor's clothes.
    /// HealthKit returns "no samples" and "zero" identically, so the app
    /// cannot obtain a measured zero — see `resolvedStepsToday`.
    func testAZeroStepDayResolvesToUnknownNotToZero() {
        XCTAssertNil(MoveRecord.resolvedStepsToday(authorized: true, count: 0))
        XCTAssertNil(MoveRecord.resolvedStepsToday(authorized: false, count: 900))
        XCTAssertEqual(MoveRecord.resolvedStepsToday(authorized: true, count: 900), 900)

        // The record TYPE still distinguishes a measured zero from
        // unknown; what changed is that this app never claims one.
        var zeroRead = emptyRecord(); zeroRead.stepsToday = 0
        XCTAssertFalse(zeroRead.isEmpty, "a measured zero is a measurement")
        var resolved = emptyRecord()
        resolved.stepsToday = MoveRecord.resolvedStepsToday(authorized: true, count: 0)
        XCTAssertTrue(resolved.isEmpty, "an unread day is unknown, and Move says so")
    }

    /// A quiet day is compared to HER baseline, never to a population, and
    /// never without one.
    func testAQuietDayNeedsHerOwnBaseline() {
        var record = emptyRecord()
        record.strengthSessionsLast7 = 2
        record.stepsToday = 400
        record.stepsBaseline = nil
        let line = MoveEnergy.nextLine(record)
        XCTAssertFalse(line?.contains("your own usual") ?? false,
                       "no baseline means no comparison")
    }

    // MARK: - Emptiness

    func testEmptyMeansUnknownNotZero() {
        XCTAssertTrue(emptyRecord().isEmpty)
        var record = emptyRecord()
        record.stepsToday = 0
        XCTAssertFalse(record.isEmpty, "a measured zero is a measurement")
    }

    private func emptyRecord() -> MoveRecord {
        MoveRecord(
            stepsToday: nil, stepsGoal: 7_500, stepsBaseline: nil,
            weeklySteps: Array(repeating: 0, count: 7),
            activeEnergy: nil, distanceKm: nil, workoutMinutesToday: nil,
            strengthSessionsLast7: 0, enteredSessionsLast7: 0
        )
    }
}
