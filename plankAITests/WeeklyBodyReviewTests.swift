import XCTest
@testable import plankAI

// WeeklyBodyReview (v9 P3) — the unified weekly read: outcome →
// mechanisms → preservation → the move. The provenance audit lives
// here: every line's floor is pinned, rising weeks stay pattern-
// only-never-blame, the mirror clause needs the full body-page
// floors, the preservation ladder runs protein × movement × the
// 1%/wk guard, and HRV speaks only against her own baseline.

final class WeeklyBodyReviewTests: XCTestCase {

    private typealias R = WeeklyBodyReview

    private func scan(daysAgo: Int, quality: Double = 0.9) -> BodyChangeRead.ScanMeta {
        .init(
            capturedAt: Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now)!,
            poseQuality: quality
        )
    }

    // MARK: - Read existence + outcome lead

    func testNothingCollectedComposesNothing() {
        XCTAssertNil(R.compose(.init()))
    }

    func testTrendLineLeadsWhenPresent() {
        var input = R.Input()
        input.trendLine = "down about 2 lb this week."
        input.trendItalic = ["down"]
        let read = R.compose(input)
        XCTAssertEqual(read?.outcome, "down about 2 lb this week.")
        XCTAssertEqual(read?.outcomeItalic, ["down"])
    }

    func testScansLeadWhenNoTrendExists() {
        var input = R.Input()
        input.scans = [scan(daysAgo: 0)]
        let read = R.compose(input)
        XCTAssertEqual(read?.outcome, "one scan kept. the next one starts the comparison.")
    }

    func testMoveAlonePassesThroughWithNeutralOutcome() {
        var input = R.Input()
        input.move = CoachSummary.compose({
            var i = CoachSummary.Input()
            i.sleepAvgHours = 5.5
            i.shortNights = 3
            i.pacing = nil
            i.weighDays14 = 3
            return i
        }())
        let read = R.compose(input)
        XCTAssertNotNil(read?.move)
        XCTAssertEqual(read?.outcome, "here's your week.")
    }

    // MARK: - The mirror clause (full floors only)

    func testMirrorClauseNeedsAgreementFloors() {
        var input = R.Input()
        input.trendLine = "down about 2 lb this week."
        input.trendDeltaKg = -0.4
        input.trendEstablished = true
        input.scans = [scan(daysAgo: 0), scan(daysAgo: 30)]
        XCTAssertTrue(R.mechanismLines(input).contains(
            "the mirror agrees · your scans show it too"))

        input.scans = [scan(daysAgo: 0), scan(daysAgo: 10)]   // span floor fails
        XCTAssertFalse(R.mechanismLines(input).contains(
            "the mirror agrees · your scans show it too"))
    }

    func testRisingWeekNeverClaimsTheMirror() {
        var input = R.Input()
        input.trendDeltaKg = 0.5
        input.trendEstablished = true
        input.scans = [scan(daysAgo: 0), scan(daysAgo: 30)]
        XCTAssertFalse(R.mechanismLines(input).contains {
            $0.contains("mirror")
        })
    }

    // MARK: - Mechanism floors

    func testProteinLineNeedsFourLoggedDays() {
        var input = R.Input()
        input.loggedDays7 = 3
        input.proteinDaysMet7 = 3
        XCTAssertTrue(R.mechanismLines(input).isEmpty)
        input.loggedDays7 = 5
        input.proteinDaysMet7 = 4
        XCTAssertEqual(R.mechanismLines(input).first,
                       "protein landed 4 of 5 logged days")
    }

    /// p71 — the ratio is a MECHANISM, not a grade: it speaks only
    /// when protein actually landed most days (InsightEngine's own
    /// ≥4 floor). "protein landed 1 of 7 logged days" explains no
    /// outcome and reads as a scold to a low-appetite reader; the
    /// preservation ladder carries that story with evidence instead.
    func testAShameShapedProteinRatioStaysQuiet() {
        var input = R.Input()
        input.loggedDays7 = 7
        input.proteinDaysMet7 = 1
        XCTAssertTrue(R.mechanismLines(input).isEmpty)
    }

    func testStrengthOutranksFeetAndFeetNeedFiveDays() {
        var input = R.Input()
        input.strengthSessions7 = 2
        input.stepsActiveDays7 = 6
        XCTAssertTrue(R.mechanismLines(input).contains("2 strength sessions kept"))
        input.strengthSessions7 = 0
        XCTAssertTrue(R.mechanismLines(input).contains("6 days on your feet"))
        input.stepsActiveDays7 = 4
        XCTAssertTrue(R.mechanismLines(input).isEmpty)
    }

    func testSleepPatternNeedsThreeCountedAndThreeShort() {
        var input = R.Input()
        input.sleepNightsCounted = 5
        input.shortNights7 = 2
        XCTAssertTrue(R.mechanismLines(input).isEmpty)
        input.shortNights7 = 3
        XCTAssertEqual(R.mechanismLines(input).first,
                       "3 short nights rode beside the line")
    }

    func testWindowDriftNeedsFourNightsUnderEleven() {
        var input = R.Input()
        input.fastAvgHours = 10.2
        input.fastNights = 3
        XCTAssertTrue(R.mechanismLines(input).isEmpty)
        input.fastNights = 5
        XCTAssertEqual(R.mechanismLines(input).first,
                       "the eating window ran late most nights")
    }

    func testSugarSpeaksOnlyWhenRisingAndNeverNamesAFood() {
        var input = R.Input()
        input.sweetDirection = .easing
        XCTAssertTrue(R.mechanismLines(input).isEmpty)
        input.sweetDirection = .rising
        XCTAssertEqual(R.mechanismLines(input), ["sugar intake rose vs last week"])
    }

    func testDoseRhythmSpeaksOnlyWhenScheduled() {
        var input = R.Input()
        input.doseTaken7 = 1
        XCTAssertTrue(R.mechanismLines(input).isEmpty)
        input.doseScheduled7 = 1
        XCTAssertEqual(R.mechanismLines(input), ["your dose landed 1 of 1"])
    }

    func testDoseRhythmNeverLeadsWithAZero() {
        // p74 — "your dose landed 0 of 1" read as a miss while the
        // week's slot was still open (filmed). Zero taken = silence;
        // the dose seat carries the slot's real standing.
        var input = R.Input()
        input.doseScheduled7 = 1
        input.doseTaken7 = 0
        XCTAssertTrue(R.mechanismLines(input).isEmpty)
    }

    func testMechanismsCapAtThree() {
        var input = R.Input()
        input.loggedDays7 = 5; input.proteinDaysMet7 = 5
        input.strengthSessions7 = 2
        input.sleepNightsCounted = 5; input.shortNights7 = 3
        input.sweetDirection = .rising
        XCTAssertEqual(R.mechanismLines(input).count, 3)
    }

    // MARK: - Recovery (D5's rendered surface)

    func testRecoverySpeaksOnlyAgainstHerBaseline() {
        XCTAssertNil(R.recoveryWord(latest: 45, baseline: nil))
        XCTAssertNil(R.recoveryWord(latest: nil, baseline: 40))
        XCTAssertEqual(R.recoveryWord(latest: 45, baseline: 40), "held steady")
        XCTAssertEqual(R.recoveryWord(latest: 50, baseline: 40), "improving")
        XCTAssertEqual(R.recoveryWord(latest: 30, baseline: 40), "dipped")
    }

    // MARK: - Preservation ladder

    func testPreservationUnknownUnderFloors() {
        var input = R.Input()
        input.loggedDays7 = 3
        input.lossRatePctPerWeek = 0.005
        let p = R.preservation(input)
        XCTAssertEqual(p?.state, .unknown)
        XCTAssertNil(p?.citation)
    }

    func testPreservationProtectedNeedsAllThreePillars() {
        var input = R.Input()
        input.loggedDays7 = 5
        input.proteinDaysMet7 = 4
        input.strengthSessions7 = 1
        input.lossRatePctPerWeek = 0.008
        let p = R.preservation(input)
        XCTAssertEqual(p?.state, .protected)
        XCTAssertEqual(p?.citation, "wycherley 2012 · ajcn")
    }

    func testPreservationAtRiskIsFastLossPlusProteinUnder() {
        var input = R.Input()
        input.loggedDays7 = 5
        input.proteinDaysMet7 = 2
        input.lossRatePctPerWeek = 0.015
        XCTAssertEqual(R.preservation(input)?.state, .atRisk)
    }

    func testPreservationWatchNamesTheMissingPillar() {
        var input = R.Input()
        input.loggedDays7 = 5
        input.proteinDaysMet7 = 5
        input.strengthSessions7 = 0
        input.stepsActiveDays7 = 2
        input.lossRatePctPerWeek = 0.006
        let p = R.preservation(input)
        XCTAssertEqual(p?.state, .watch)
        XCTAssertTrue(p?.line.contains("movement is the missing pillar") == true)
    }

    func testFeetCanHoldTheMovementPillar() {
        var input = R.Input()
        input.loggedDays7 = 5
        input.proteinDaysMet7 = 4
        input.strengthSessions7 = 0
        input.stepsActiveDays7 = 6
        input.lossRatePctPerWeek = 0.006
        XCTAssertEqual(R.preservation(input)?.state, .protected)
    }

    func testConnectDoorOpensOnlyWhenWorkoutsUngranted() {
        var input = R.Input()
        input.loggedDays7 = 5
        input.lossRatePctPerWeek = 0.005
        XCTAssertEqual(R.preservation(input)?.connectDoor, true)
        input.strengthSessions7 = 0
        XCTAssertEqual(R.preservation(input)?.connectDoor, false)
    }

    func testLeanGarnishRidesWithProvenance() {
        var input = R.Input()
        input.loggedDays7 = 5
        input.proteinDaysMet7 = 4
        input.strengthSessions7 = 1
        input.lossRatePctPerWeek = 0.006
        input.leanLine = "your scale reads 48.9 kg lean"
        XCTAssertTrue(R.preservation(input)?.line.hasSuffix("your scale reads 48.9 kg lean") == true)
    }
}
