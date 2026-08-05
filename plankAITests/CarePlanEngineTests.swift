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

    // MARK: - The second act (mission 3: the day never empties)

    func testStandardDayClosesWithReflectionAndPreparation() {
        let plan = CarePlanEngine.compose(.init(day: day(beats: fullBeats)))
        XCTAssertEqual(plan.closing, [.reflect, .prepare])
    }

    func testGentleDayClosesWithReflectionAndRecovery() {
        let plan = CarePlanEngine.compose(.init(
            day: day(beats: fullBeats),
            yesterdayFeeling: "tender"
        ))
        XCTAssertEqual(plan.closing, [.reflect, .recover])
    }

    func testCelebrationLeadsTheClosing() {
        let plan = CarePlanEngine.compose(.init(
            day: day(beats: fullBeats),
            isCelebrationDay: true
        ))
        XCTAssertEqual(plan.closing.first, .celebrate)
        XCTAssertTrue(plan.closing.contains(.reflect))
    }

    func testUnenrolledDayHasNoClosing() {
        XCTAssertTrue(CarePlanEngine.compose(.init(day: nil)).closing.isEmpty)
    }

    func testEnrolledDayAlwaysLeads() {
        // Founder law: an enrolled day always has a purpose — even a
        // beatless day floors to the breath.
        let empty = PrescriptionEngineV2.Day(
            archetype: .rest, beats: [], weighInIsStaleFallback: false, programDay: 5
        )
        let plan = CarePlanEngine.compose(.init(day: empty))
        XCTAssertNotNil(plan.lead)
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

    // MARK: - v9 P4: the body-outcome axis

    func testPreservationAtRiskPromotesProteinWithItsOwnReason() {
        let plan = CarePlanEngine.compose(.init(
            day: day(beats: fullBeats), preservationAtRisk: true
        ))
        XCTAssertTrue(plan.leadIsPromoted)
        XCTAssertEqual(plan.lead?.because,
                       "the week ran fast with protein under. protein first protects muscle")
        if case .snapMeal = plan.lead!.beat {} else {
            XCTFail("the preservation promotion must lead with the plate")
        }
    }

    func testRapidLossOutranksThePreservationPattern() {
        let plan = CarePlanEngine.compose(.init(
            day: day(beats: fullBeats),
            lossRatePctPerWeek: 0.02,
            trendIsEstablished: true,
            preservationAtRisk: true
        ))
        XCTAssertEqual(plan.lead?.because,
                       "losing fast. protein first protects muscle")
    }

    func testPlateauReachesTheLeadReasonAsSupport() {
        let plan = CarePlanEngine.compose(.init(
            day: day(beats: fullBeats), isPlateauWeek: true
        ))
        XCTAssertFalse(plan.leadIsPromoted)
        XCTAssertEqual(plan.lead?.because,
                       "plateau week. your body's adjusting. the plan holds")
    }

    func testPlateauNeverOverridesAClinicalPromotion() {
        let plan = CarePlanEngine.compose(.init(
            day: day(beats: fullBeats),
            preservationAtRisk: true,
            isPlateauWeek: true
        ))
        XCTAssertTrue(plan.lead?.because?.contains("protein first") == true)
    }

    func testDoseDayNeverWearsThePromotionMark() {
        let plan = CarePlanEngine.compose(.init(
            day: day(beats: fullBeats),
            isDoseDay: true,
            preservationAtRisk: true
        ))
        XCTAssertFalse(plan.leadIsPromoted)
        if case .medication = plan.lead!.beat {} else {
            XCTFail("dose day must still lead with the medication mark")
        }
    }

    func testGentleDayStaysUnadorned() {
        let plan = CarePlanEngine.compose(.init(
            day: day(beats: fullBeats),
            yesterdayFeeling: "tender",
            preservationAtRisk: true
        ))
        XCTAssertEqual(plan.tone, .gentle)
        XCTAssertFalse(plan.leadIsPromoted)
    }

    // MARK: - v9 P1: the weekly scan invitation (offered, never debt)

    func testScanDayOffersTheScanAndNeverCountsIt() {
        let plan = CarePlanEngine.compose(.init(
            day: day(beats: fullBeats), isScanDay: true, hasAnyScan: true
        ))
        XCTAssertTrue(plan.offered.contains { move in
            if case .bodyScan = move.beat { return true } else { return false }
        })
        XCTAssertFalse(plan.actionableBeats.contains { beat in
            if case .bodyScan = beat { return true } else { return false }
        })
    }

    func testOrdinaryDayNeverOffersTheScan() {
        let plan = CarePlanEngine.compose(.init(day: day(beats: fullBeats)))
        XCTAssertFalse(plan.offered.contains { move in
            if case .bodyScan = move.beat { return true } else { return false }
        })
    }

    func testGentleDayDropsTheScanWithEveryOtherInvitation() {
        let plan = CarePlanEngine.compose(.init(
            day: day(beats: fullBeats), yesterdayFeeling: "tender",
            isScanDay: true, hasAnyScan: true
        ))
        XCTAssertEqual(plan.tone, .gentle)
        XCTAssertTrue(plan.offered.isEmpty)
    }

    func testFirstScanSpeaksItsOwnLine() {
        let first = CarePlanEngine.compose(.init(
            day: day(beats: fullBeats), isScanDay: true, hasAnyScan: false
        ))
        let repeatDay = CarePlanEngine.compose(.init(
            day: day(beats: fullBeats), isScanDay: true, hasAnyScan: true
        ))
        let firstLine = first.offered.first { move in
            if case .bodyScan = move.beat { return true } else { return false }
        }?.because
        let repeatLine = repeatDay.offered.first { move in
            if case .bodyScan = move.beat { return true } else { return false }
        }?.because
        XCTAssertEqual(firstLine, "your record starts with one scan")
        XCTAssertEqual(repeatLine, "scan day. same spot, same light")
    }
}

// MARK: - The letter's memory (v7 phase 3)
//
// First coverage the cascade has ever had — pinned around the new
// clauses so the letter's tiers and the once-ever win can't drift.

final class DailyBriefLetterTests: XCTestCase {

    private func ctx(
        programDay: Int = 12,
        gap: Int = 0,
        gapSteps: Int? = nil,
        firstDownWeek: Bool = false,
        tender: Bool = false
    ) -> DailyBriefEngine.Context {
        .init(
            name: nil,
            programDay: programDay,
            archetype: .balanced,
            isWeighInDay: false,
            weighInIsStaleFallback: false,
            emaDelta7dKg: nil,
            lossRatePctPerWeek: nil,
            showedUpCount: 5,
            daysSinceLastOpen: gap,
            promiseJustKept: false,
            proteinTargetG: 90,
            yesterdayStepsHitGoal: false,
            maintenanceMode: false,
            glp1Cohort: .generalWL,
            dayKey: "2026-07-27",
            gapStepsDailyAvg: gapSteps,
            isFirstDownWeekEver: firstDownWeek,
            yesterdayFeeling: tender ? "tender" : nil
        )
    }

    func testLightGapSpeaksLightly() {
        let brief = DailyBriefEngine.brief(for: ctx(gap: 2))
        XCTAssertTrue(brief.line.contains("weekends happen"))
    }

    func testMidGapCitesTheWatchedFact() {
        let brief = DailyBriefEngine.brief(for: ctx(gap: 8, gapSteps: 6_100))
        XCTAssertTrue(brief.line.contains("back after 8 days"))
        XCTAssertTrue(brief.second?.contains("6,100") ?? false)
    }

    func testMidGapWithoutStepsNeverClaimsThem() {
        let brief = DailyBriefEngine.brief(for: ctx(gap: 8))
        XCTAssertFalse(brief.second?.contains("averaged") ?? false)
    }

    func testLongGapSoftensToOnePlate() {
        let brief = DailyBriefEngine.brief(for: ctx(gap: 21))
        XCTAssertTrue(brief.line.contains("still day 12"))
        XCTAssertTrue(brief.second?.contains("one plate") ?? false)
    }

    func testFirstDownWeekIsNamedOnce() {
        let brief = DailyBriefEngine.brief(for: ctx(firstDownWeek: true))
        XCTAssertTrue(brief.line.contains("first down week"))
    }

    func testTenderYesterdayOutranksTheWin() {
        // Care outranks celebration: a tender evening gets the
        // gentle morning even on a milestone day.
        let brief = DailyBriefEngine.brief(for: ctx(firstDownWeek: true, tender: true))
        XCTAssertTrue(brief.line.contains("tender"))
    }

    func testComebackOutranksTenderAndWin() {
        let brief = DailyBriefEngine.brief(
            for: ctx(gap: 5, gapSteps: nil, firstDownWeek: true, tender: true)
        )
        XCTAssertTrue(brief.line.contains("back after 5 days"))
    }
}
