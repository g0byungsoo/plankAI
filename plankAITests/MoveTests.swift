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

    func testAnEmptyWeekIsStatedWithoutAVerdict() {
        let line = MoveEnergy.nextLine(emptyRecord())
        XCTAssertNotNil(line)
        for word in ["failed", "missed", "should", "behind", "only"] {
            XCTAssertFalse(line?.contains(word) ?? false, line ?? "")
        }
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
