import XCTest
@testable import plankAI

final class WeightUnitTests: XCTestCase {

    func testKgDisplayIsIdentityRoundedToOneDecimal() {
        XCTAssertEqual(WeightUnit.kg.display(fromKg: 70.0), 70.0, accuracy: 0.05)
        XCTAssertEqual(WeightUnit.kg.display(fromKg: 70.456), 70.5, accuracy: 0.05)
    }

    func testLbDisplayConvertsFromKg() {
        XCTAssertEqual(WeightUnit.lb.display(fromKg: 70.0), 154.3, accuracy: 0.05)
    }

    func testRoundTripAcrossUnits() {
        for kg in [50.0, 70.0, 90.0, 120.0] {
            for unit in [WeightUnit.kg, WeightUnit.lb] {
                let displayed = unit.display(fromKg: kg)
                let backToKg = unit.toKg(displayed: displayed)
                let displayedAgain = unit.display(fromKg: backToKg)
                XCTAssertEqual(displayed, displayedAgain, accuracy: 0.1,
                               "round-trip drift for \(unit.label) at kg=\(kg)")
            }
        }
    }

    func testStepDeltas() {
        XCTAssertEqual(WeightUnit.kg.smallStep, 0.1, accuracy: 0.0001)
        XCTAssertEqual(WeightUnit.kg.largeStep, 1.0, accuracy: 0.0001)
        XCTAssertEqual(WeightUnit.lb.smallStep, 0.2, accuracy: 0.0001)
        XCTAssertEqual(WeightUnit.lb.largeStep, 2.0, accuracy: 0.0001)
    }

    func testDisplayRangeEnvelopesTypicalAdultWeights() {
        XCTAssertTrue(WeightUnit.kg.displayRange.contains(50))
        XCTAssertTrue(WeightUnit.kg.displayRange.contains(150))
        XCTAssertTrue(WeightUnit.lb.displayRange.contains(110))
        XCTAssertTrue(WeightUnit.lb.displayRange.contains(330))
    }

    func testFormattedHelper() {
        XCTAssertEqual(WeightUnit.kg.formatted(fromKg: 70.0), "70.0 kg")
        XCTAssertEqual(WeightUnit.lb.formatted(fromKg: 70.0), "154.3 lb")
    }
}

final class WeightAnalyticsTests: XCTestCase {

    func testDisplayGoalKgCapsAtTenPercentLoss() {
        XCTAssertEqual(WeightAnalytics.displayGoalKg(startingKg: 70, declaredGoalKg: 60),
                       63.0, accuracy: 0.05)
    }

    func testDisplayGoalKgPassesThroughWhenWithinCap() {
        XCTAssertEqual(WeightAnalytics.displayGoalKg(startingKg: 70, declaredGoalKg: 65),
                       65.0, accuracy: 0.05)
    }

    func testDisplayGoalKgPassesThroughGainTarget() {
        XCTAssertEqual(WeightAnalytics.displayGoalKg(startingKg: 70, declaredGoalKg: 75),
                       75.0, accuracy: 0.05)
    }

    func testGoalProgressFraction() {
        // 70 → 65 with declared 60 caps to 63. Total needed 7, progressed 5.
        let p = WeightAnalytics.goalProgress(startingKg: 70, currentKg: 65, declaredGoalKg: 60)
        XCTAssertNotNil(p)
        XCTAssertEqual(p ?? 0, 5.0/7.0, accuracy: 0.001)
    }

    func testGoalProgressNilWhenAlreadyAtGoal() {
        XCTAssertNil(WeightAnalytics.goalProgress(startingKg: 70, currentKg: 70, declaredGoalKg: 70))
    }

    func testGoalProgressClampsToOneWhenExceeded() {
        let p = WeightAnalytics.goalProgress(startingKg: 70, currentKg: 60, declaredGoalKg: 65)
        XCTAssertNotNil(p)
        XCTAssertEqual(p ?? 0, 1.0, accuracy: 0.01)
    }

    func testGoalProgressClampsToZeroOnGain() {
        let p = WeightAnalytics.goalProgress(startingKg: 70, currentKg: 75, declaredGoalKg: 65)
        XCTAssertNotNil(p)
        XCTAssertEqual(p ?? 0, 0.0, accuracy: 0.01)
    }

    func testIsStalledFalseOnEmpty() {
        XCTAssertFalse(WeightAnalytics.isStalled(logs: []))
    }
}

/// Medical-grade Phase 5 — the % total-body-weight-loss evidence flywheel.
/// Tests target the pure `dueMilestones` core (no UserDefaults / Analytics
/// side effects) so the math + milestone gating + the >=5% TBWL threshold
/// are pinned. Correctness matters here: this is the evidence substrate.
final class WeightOutcomeInstrumentationTests: XCTestCase {

    private let start = Date(timeIntervalSince1970: 1_700_000_000)  // fixed anchor

    private func at(weeks: Double) -> Date {
        start.addingTimeInterval(weeks * 7 * 24 * 3600)
    }

    private func due(enroll: Double?, current: Double?, weeks: Double)
        -> [WeightOutcomeInstrumentation.Milestone] {
        WeightOutcomeInstrumentation.dueMilestones(
            startDate: start, enrollmentWeightKg: enroll,
            latestWeightKg: current, now: at(weeks: weeks))
    }

    func testNoMilestoneBeforeTwelveWeeks() {
        XCTAssertTrue(due(enroll: 70, current: 66, weeks: 11.9).isEmpty)
    }

    func testTwelveWeekMilestoneFires() {
        XCTAssertEqual(due(enroll: 70, current: 66, weeks: 12).map(\.week), [12])
    }

    func testCumulativeMilestonesAtThirtyWeeks() {
        XCTAssertEqual(due(enroll: 70, current: 63, weeks: 30).map(\.week), [12, 26])
    }

    func testAllMilestonesPastFiftyTwoWeeks() {
        XCTAssertEqual(due(enroll: 70, current: 63, weeks: 60).map(\.week), [12, 26, 52])
    }

    func testTbwlPercentAndFivePercentFlag() {
        // 70 → 63 = exactly 10% loss.
        let m = due(enroll: 70, current: 63, weeks: 12).first
        XCTAssertEqual(m?.tbwlPct ?? 0, 10.0, accuracy: 0.05)
        XCTAssertEqual(m?.achieved5pct, true)
    }

    func testFivePercentBoundaryIsInclusive() {
        // 70 → 66.5 = exactly 5.0%.
        let m = due(enroll: 70, current: 66.5, weeks: 12).first
        XCTAssertEqual(m?.tbwlPct ?? 0, 5.0, accuracy: 0.05)
        XCTAssertEqual(m?.achieved5pct, true)
    }

    func testJustUnderFivePercentNotAchieved() {
        // 70 → 66.6 = 4.857% loss.
        XCTAssertEqual(due(enroll: 70, current: 66.6, weeks: 12).first?.achieved5pct, false)
    }

    func testWeightGainKeepsMilestoneWithNegativeTbwl() {
        // 70 → 72 = gain; the milestone is still recorded (real signal),
        // but the >=5% flag is false.
        let m = due(enroll: 70, current: 72, weeks: 12).first
        XCTAssertEqual(m?.week, 12)
        XCTAssertLessThan(m?.tbwlPct ?? 0, 0)
        XCTAssertEqual(m?.achieved5pct, false)
    }

    func testNoEnrollmentWeightEmitsNothing() {
        XCTAssertTrue(due(enroll: nil, current: 66, weeks: 30).isEmpty)
    }

    func testNoCurrentWeightEmitsNothing() {
        // Never weighed in → no number to invent (data-provenance).
        XCTAssertTrue(due(enroll: 70, current: nil, weeks: 30).isEmpty)
    }

    func testDaysSinceStartTracksElapsed() {
        XCTAssertEqual(due(enroll: 70, current: 66, weeks: 12).first?.daysSinceStart, 84)
    }
}

/// Medical-grade Phase 2.3 — the lean-mass-protection protein floor. The
/// flagship clinical differentiator: the GLP-1 cohort gets the protective
/// top of the 1.2-1.6 g/kg band because appetite suppression + rapid loss
/// carries the highest sarcopenia risk.
final class ClinicalTargetsTests: XCTestCase {

    func testBaselineProteinIsTwelveTenthsPerKg() {
        // 70 kg, non-GLP-1 → 1.2 * 70 = 84 g.
        XCTAssertEqual(ClinicalTargets.proteinFloorGrams(weightKg: 70, isGLP1: false), 84)
    }

    func testGLP1ProteinIsSixteenTenthsPerKg() {
        // 70 kg, GLP-1 → 1.6 * 70 = 112 g (the muscle-preservation top of band).
        XCTAssertEqual(ClinicalTargets.proteinFloorGrams(weightKg: 70, isGLP1: true), 112)
    }

    func testGLP1FloorAlwaysExceedsBaselineAtSameWeight() {
        // The flagship differentiator: the GLP-1 cohort gets more protein.
        for kg in [60.0, 75.0, 90.0, 105.0] {
            XCTAssertGreaterThan(
                ClinicalTargets.proteinFloorGrams(weightKg: kg, isGLP1: true),
                ClinicalTargets.proteinFloorGrams(weightKg: kg, isGLP1: false),
                "GLP-1 floor should exceed baseline at kg=\(kg)")
        }
    }

    func testLowerClampAtEightyGrams() {
        // 50 kg non-GLP-1 → 60 raw, clamped up to the 80 g floor.
        XCTAssertEqual(ClinicalTargets.proteinFloorGrams(weightKg: 50, isGLP1: false), 80)
    }

    func testUpperClampAtOneSixtyGrams() {
        // 110 kg GLP-1 → 176 raw, clamped down to the 160 g ceiling.
        XCTAssertEqual(ClinicalTargets.proteinFloorGrams(weightKg: 110, isGLP1: true), 160)
    }
}
