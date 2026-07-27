import XCTest
@testable import plankAI

// CarePlanEngine (app v7, docs/app_v7/00_THESIS.md §4) — the day's
// composer. These tables pin the laws: ≤3 actionable moves, gentle
// days compose to one, observations are never moves, the method is
// never required, because-clauses are provenance-only.

final class CarePlanEngineTests: XCTestCase {

    // MARK: - Fixtures

    private func day(
        programDay: Int = 12,
        beats: [ProgramDayPrescription]
    ) -> PrescriptionEngineV2.Day {
        PrescriptionEngineV2.Day(
            archetype: .protein,
            beats: beats,
            weighInIsStaleFallback: false,
            programDay: programDay
        )
    }

    private let fullBeats: [ProgramDayPrescription] = [
        .snapMeal,
        .workout(tier: .medium, minutes: 10, bodyFocus: nil),
        .lesson(lessonId: nil),
        .steps(goal: 7_500),
        .weighIn,
    ]

    // MARK: - Shape laws

    func testStandardDayLeadsWithOneThingAndCapsAtThreeActionable() {
        let plan = CarePlanEngine.compose(.init(day: day(beats: fullBeats)))
        XCTAssertEqual(plan.tone, .standard)
        XCTAssertNotNil(plan.lead)
        XCTAssertLessThanOrEqual(plan.actionableBeats.count, 3)
    }

    func testStepsIsNeverAMove() {
        let plan = CarePlanEngine.compose(.init(day: day(beats: fullBeats)))
        let all = plan.actionableBeats + plan.offered.map(\.beat)
        XCTAssertFalse(all.contains { beat in
            if case .steps = beat { return true } else { return false }
        })
    }

    func testLessonIsNeverRequired() {
        let plan = CarePlanEngine.compose(.init(day: day(beats: fullBeats)))
        XCTAssertFalse(plan.actionableBeats.contains { beat in
            if case .lesson = beat { return true } else { return false }
        })
    }

    func testWorkoutIsOfferedNotOwed() {
        let plan = CarePlanEngine.compose(.init(day: day(beats: fullBeats)))
        XCTAssertFalse(plan.supporting.contains { move in
            if case .workout = move.beat { return true } else { return false }
        })
        XCTAssertTrue(plan.offered.contains { move in
            if case .workout = move.beat { return true } else { return false }
        })
    }

    func testWeighInRidesAsSupportingWithRing() {
        let plan = CarePlanEngine.compose(.init(day: day(beats: fullBeats)))
        XCTAssertTrue(plan.supporting.contains { move in
            if case .weighIn = move.beat { return true } else { return false }
        })
    }

    func testNoDayComposesEmptyPlan() {
        let plan = CarePlanEngine.compose(.init(day: nil))
        XCTAssertNil(plan.lead)
        XCTAssertTrue(plan.supporting.isEmpty)
        XCTAssertTrue(plan.offered.isEmpty)
    }

    // MARK: - Tone: gentle days

    func testTenderYesterdayComposesGentleSingleMove() {
        let plan = CarePlanEngine.compose(.init(
            day: day(beats: fullBeats),
            yesterdayFeeling: "tender"
        ))
        XCTAssertEqual(plan.tone, .gentle)
        XCTAssertNotNil(plan.lead)
        XCTAssertTrue(plan.supporting.isEmpty)
        XCTAssertTrue(plan.offered.isEmpty)
        XCTAssertEqual(plan.actionableBeats.count, 1)
        XCTAssertNotNil(plan.lead?.because)
    }

    func testShortNightComposesGentle() {
        let plan = CarePlanEngine.compose(.init(
            day: day(beats: fullBeats),
            sleepHoursLastNight: 5.4
        ))
        XCTAssertEqual(plan.tone, .gentle)
        XCTAssertEqual(plan.actionableBeats.count, 1)
        XCTAssertTrue(plan.lead?.because?.contains("short night") ?? false)
    }

    func testFullNightStaysStandard() {
        let plan = CarePlanEngine.compose(.init(
            day: day(beats: fullBeats),
            sleepHoursLastNight: 7.6
        ))
        XCTAssertEqual(plan.tone, .standard)
    }

    func testComebackAfterDaysAwayComposesGentle() {
        let plan = CarePlanEngine.compose(.init(
            day: day(beats: fullBeats),
            daysSinceLastOpen: 6
        ))
        XCTAssertEqual(plan.tone, .gentle)
        XCTAssertTrue(plan.lead?.because?.contains("back after 6 days") ?? false)
    }

    // MARK: - Lead promotions (provenance-only)

    func testRapidLossPromotesProteinFirstSnap() {
        let plan = CarePlanEngine.compose(.init(
            day: day(beats: fullBeats),
            lossRatePctPerWeek: 0.014,
            trendIsEstablished: true
        ))
        guard case .snapMeal = plan.lead?.beat else {
            return XCTFail("expected snap lead")
        }
        XCTAssertTrue(plan.lead?.because?.contains("protein") ?? false)
    }

    func testRapidLossNeedsEstablishedTrend() {
        let plan = CarePlanEngine.compose(.init(
            day: day(beats: fullBeats),
            lossRatePctPerWeek: 0.02,
            trendIsEstablished: false
        ))
        XCTAssertNil(plan.lead?.because)
    }

    func testProteinMissYesterdayPromotesWithDeficitClause() {
        let plan = CarePlanEngine.compose(.init(
            day: day(beats: fullBeats),
            yesterdayProteinG: 40,
            proteinTargetG: 90
        ))
        XCTAssertEqual(plan.lead?.because, "yesterday landed 50g under your protein floor")
    }

    func testNearMissYesterdayStaysQuiet() {
        // 15g under is a normal day, not a care thread.
        let plan = CarePlanEngine.compose(.init(
            day: day(beats: fullBeats),
            yesterdayProteinG: 75,
            proteinTargetG: 90
        ))
        XCTAssertNil(plan.lead?.because)
    }

    func testUnloggedYesterdayNeverClaimsDeficit() {
        // The assembler passes nil for unlogged days; nil must never
        // produce a deficit clause (absence is not deficit).
        let plan = CarePlanEngine.compose(.init(
            day: day(beats: fullBeats),
            yesterdayProteinG: nil,
            proteinTargetG: 90
        ))
        XCTAssertNil(plan.lead?.because)
    }

    // MARK: - Determinism

    func testSameInputSamePlan() {
        let input = CarePlanEngine.Input(
            day: day(beats: fullBeats),
            yesterdayFeeling: "okay",
            sleepHoursLastNight: 7.1,
            yesterdayProteinG: 40,
            proteinTargetG: 90
        )
        XCTAssertEqual(CarePlanEngine.compose(input), CarePlanEngine.compose(input))
    }
}
