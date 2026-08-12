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

    // MARK: - The walking action (v25 E1 — D5 ledgered supersession:
    // a gap against the program's OWNED goal is an ask; a passive
    // count stays a receipt. The raw .steps prescription beat still
    // never promotes — testStepsIsNeverAMove above pins that path.)

    private func walkInput(
        stepsToday: Int? = 5_900,
        stepGoal: Int? = 8_000,
        hour: Int = 15,
        externalWorkout: Bool = false,
        largeMeal: Bool = false,
        walkTiming: String? = nil,
        tender: Bool = false,
        doseDay: Bool = false
    ) -> CarePlanEngine.Input {
        .init(
            day: day(beats: fullBeats),
            yesterdayFeeling: tender ? "tender" : nil,
            isDoseDay: doseDay,
            stepsToday: stepsToday,
            stepGoal: stepGoal,
            hourOfDay: hour,
            externalWorkoutToday: externalWorkout,
            largeMealLoggedRecently: largeMeal,
            walkTimingWord: walkTiming
        )
    }

    private func walkMove(_ plan: CarePlanEngine.Plan) -> CarePlanEngine.Move? {
        plan.supporting.first { move in
            if case .steps = move.beat { return true } else { return false }
        }
    }

    func testWalkComposesWhenGapWithinReach() {
        let plan = CarePlanEngine.compose(walkInput())
        let walk = walkMove(plan)
        XCTAssertNotNil(walk)
        XCTAssertNotNil(walk?.because)
        XCTAssertTrue(walk?.because?.contains("2,100") ?? false)
    }

    func testWalkCountsTowardActionableCap() {
        let plan = CarePlanEngine.compose(walkInput())
        XCTAssertLessThanOrEqual(plan.actionableBeats.count, 3)
    }

    func testWalkAbsentBeforeAfternoon() {
        XCTAssertNil(walkMove(CarePlanEngine.compose(walkInput(hour: 11))))
    }

    func testWalkAbsentWhenGapTooLarge() {
        // 7,000 of 8,000 left is not an afternoon ask — an absurd
        // recommendation never renders.
        XCTAssertNil(walkMove(CarePlanEngine.compose(walkInput(stepsToday: 1_000))))
    }

    func testWalkAbsentWhenGoalCrossed() {
        XCTAssertNil(walkMove(CarePlanEngine.compose(walkInput(stepsToday: 8_200))))
    }

    func testWalkAbsentWithoutStepsData() {
        XCTAssertNil(walkMove(CarePlanEngine.compose(walkInput(stepsToday: nil))))
        XCTAssertNil(walkMove(CarePlanEngine.compose(walkInput(stepGoal: nil))))
    }

    func testWalkAbsentOnGentleDays() {
        let plan = CarePlanEngine.compose(walkInput(tender: true))
        XCTAssertEqual(plan.tone, .gentle)
        XCTAssertNil(walkMove(plan))
    }

    func testWalkAbsentWhenExternalWorkoutAbsorbed() {
        XCTAssertNil(walkMove(CarePlanEngine.compose(walkInput(externalWorkout: true))))
    }

    func testWalkAbsentWhenTimingOff() {
        XCTAssertNil(walkMove(CarePlanEngine.compose(walkInput(walkTiming: "off"))))
    }

    func testPostMealVariantBypassesHourGate() {
        let plan = CarePlanEngine.compose(walkInput(hour: 13, largeMeal: true))
        let walk = walkMove(plan)
        XCTAssertNotNil(walk)
        XCTAssertTrue(walk?.because?.contains("settle") ?? false)
    }

    func testWalkYieldsToTheSupportingCapOnDoseDays() {
        // Dose day: medication leads, the keystone demotes to
        // support 1, the weigh-in takes support 2 — the cap holds
        // and the walk yields.
        let plan = CarePlanEngine.compose(walkInput(doseDay: true))
        XCTAssertLessThanOrEqual(plan.supporting.count, 2)
        XCTAssertNil(walkMove(plan))
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

// MARK: - v25 E4 DAY TWO — the morning read

final class MorningReadTests: XCTestCase {

    private func ctx(
        programDay: Int = 3,
        gap: Int = 0,
        plates: Int = 0,
        protein: Int? = nil,
        kcal: Int? = nil,
        weighed: Bool = false,
        weighCount: Int = 0,
        kept: Int = 0,
        feeling: String? = nil,
        proteinTarget: Int? = 90,
        suppressed: Bool = false,
        promiseKept: Bool = false,
        trendEstablished: Bool = false
    ) -> DailyBriefEngine.Context {
        var c = DailyBriefEngine.Context(
            name: nil,
            programDay: programDay,
            archetype: .balanced,
            isWeighInDay: false,
            weighInIsStaleFallback: false,
            emaDelta7dKg: nil,
            lossRatePctPerWeek: nil,
            showedUpCount: 5,
            daysSinceLastOpen: gap,
            promiseJustKept: promiseKept,
            proteinTargetG: proteinTarget,
            yesterdayStepsHitGoal: false,
            maintenanceMode: false,
            glp1Cohort: .generalWL,
            dayKey: "2026-08-11",
            yesterdayFeeling: feeling
        )
        c.trendIsEstablished = trendEstablished
        c.yesterdayPlateCount = plates
        c.yesterdayProteinG = protein
        c.yesterdayKcal = kcal
        c.yesterdayWeighedIn = weighed
        c.yesterdayKeptBeats = kept
        c.weighInCount = weighCount
        c.numericSuppressed = suppressed
        return c
    }

    // — the receipt

    func testNoRecordYesterdayMeansNoReceipt() {
        // An unlogged day is absence, not zero — no receipt row.
        XCTAssertNil(DailyBriefEngine.brief(for: ctx(plates: 0)).receipt)
    }

    func testDayOneNeverCarriesAReceipt() {
        let brief = DailyBriefEngine.brief(for: ctx(programDay: 1, plates: 2, protein: 70))
        XCTAssertNil(brief.receipt)
    }

    func testReceiptLedgersPlatesProteinWeighInAndFeeling() {
        // Day 9: the archetype clause claims the line, so the ledger
        // row carries the whole record.
        let brief = DailyBriefEngine.brief(for: ctx(
            programDay: 9, plates: 2, protein: 76, weighed: true, feeling: "proud"
        ))
        let line = brief.receipt?.ledgerLine ?? ""
        XCTAssertTrue(line.contains("2 plates"))
        XCTAssertTrue(line.contains("76 g protein"))
        XCTAssertTrue(line.contains("weighed in"))
        XCTAssertTrue(line.contains("closed proud"))
    }

    func testProseAndLedgerNeverSayTheSameNumbersTwice() {
        // Frame-caught: the day-two clause reads the plates back in
        // prose; the ledger row directly beneath must not repeat
        // them — it keeps only what the prose didn't say.
        let brief = DailyBriefEngine.brief(for: ctx(
            programDay: 2, plates: 5, protein: 206, weighed: true
        ))
        XCTAssertEqual(brief.clause, "day_two")
        let line = brief.receipt?.ledgerLine ?? ""
        XCTAssertFalse(line.contains("plates"))
        XCTAssertFalse(line.contains("protein"))
        XCTAssertTrue(line.contains("weighed in"))
    }

    func testNumericSuppressionStripsReceiptNumbers() {
        let brief = DailyBriefEngine.brief(for: ctx(
            plates: 2, protein: 76, kcal: 1450, weighed: true, suppressed: true
        ))
        XCTAssertNil(brief.receipt?.proteinG)
        XCTAssertNil(brief.receipt?.kcal)
        // The words stay: plates + weighed-in are not numerals.
        XCTAssertTrue(brief.receipt?.ledgerLine.contains("2 plates") ?? false)
        XCTAssertFalse(brief.receipt?.ledgerLine.contains("76") ?? true)
    }

    func testWeighInAloneEarnsAReceipt() {
        // L5 closed: a day-1 weigh-in is no longer silent on day 2.
        let brief = DailyBriefEngine.brief(for: ctx(programDay: 2, weighed: true))
        XCTAssertTrue(brief.receipt?.ledgerLine.contains("weighed in") ?? false)
    }

    // — the day-two clause

    func testDayTwoReadsTheFileBack() {
        let brief = DailyBriefEngine.brief(for: ctx(
            programDay: 2, plates: 2, protein: 76
        ))
        XCTAssertEqual(brief.clause, "day_two")
        XCTAssertTrue(brief.line.contains("your file started"))
        XCTAssertTrue(brief.line.contains("2 plates"))
        XCTAssertTrue(brief.second?.contains("76 g protein") ?? false)
        XCTAssertTrue(brief.second?.contains("90g") ?? false)
    }

    func testDayTwoWithNothingLoggedFallsThrough() {
        let brief = DailyBriefEngine.brief(for: ctx(programDay: 2, plates: 0))
        XCTAssertNotEqual(brief.clause, "day_two")
        XCTAssertNil(brief.receipt)
    }

    func testWeekOneMorningNamesTheHeldFloor() {
        let brief = DailyBriefEngine.brief(for: ctx(
            programDay: 4, plates: 3, protein: 95
        ))
        XCTAssertEqual(brief.clause, "yesterday_read")
        XCTAssertTrue(brief.line.contains("held your protein floor"))
        XCTAssertTrue(brief.second?.contains("95g") ?? false)
    }

    func testWeekOneMorningStatesTheFileWithoutJudgment() {
        let brief = DailyBriefEngine.brief(for: ctx(
            programDay: 4, plates: 1, protein: 30
        ))
        XCTAssertEqual(brief.clause, "yesterday_read")
        XCTAssertTrue(brief.line.contains("one plate"))
        // Anti-shame: the miss is never graded; the floor is stated.
        XCTAssertFalse(brief.line.contains("only"))
        XCTAssertFalse(brief.line.contains("missed"))
        XCTAssertTrue(brief.second?.contains("90g") ?? false)
    }

    func testZeroProteinPlateNeverPrintsZeroGrams() {
        let brief = DailyBriefEngine.brief(for: ctx(
            programDay: 4, plates: 1, protein: 0
        ))
        XCTAssertFalse(brief.line.contains("0g"))
        XCTAssertFalse(brief.second?.contains("about 0g") ?? false)
    }

    func testYesterdayReadRetiresAfterWeekOne() {
        let brief = DailyBriefEngine.brief(for: ctx(
            programDay: 9, plates: 2, protein: 76
        ))
        XCTAssertNotEqual(brief.clause, "yesterday_read")
        // The receipt still rides — the ledger outlives the clause.
        XCTAssertNotNil(brief.receipt)
    }

    func testSuppressedCohortNeverGetsTheNumbersClause() {
        let brief = DailyBriefEngine.brief(for: ctx(
            programDay: 3, plates: 2, protein: 76, suppressed: true
        ))
        XCTAssertNotEqual(brief.clause, "yesterday_read")
        XCTAssertNotEqual(brief.clause, "day_two")
    }

    func testTenderStillOutranksTheYesterdayRead() {
        let brief = DailyBriefEngine.brief(for: ctx(
            programDay: 3, plates: 3, protein: 95, feeling: "tender"
        ))
        XCTAssertEqual(brief.clause, "tender")
    }

    func testComebackOutranksTheYesterdayRead() {
        let brief = DailyBriefEngine.brief(for: ctx(
            programDay: 5, gap: 2, plates: 2, protein: 60
        ))
        XCTAssertEqual(brief.clause, "comeback_short")
    }

    // — the forming line (L5)

    func testFirstWeighInEarnsTheFormingLine() {
        let brief = DailyBriefEngine.brief(for: ctx(
            programDay: 2, plates: 1, protein: 40, weighed: true, weighCount: 1
        ))
        XCTAssertTrue(brief.mechanism?.contains("line is forming") ?? false)
    }

    func testEstablishedTrendDropsTheFormingLine() {
        let brief = DailyBriefEngine.brief(for: ctx(
            programDay: 4, plates: 2, protein: 95, weighed: true,
            weighCount: 6, trendEstablished: true
        ))
        XCTAssertNil(brief.mechanism)
    }

    // — the intention read-back (E8.2: an intention that never
    //   resurfaces is theater; the close's drafted plan pays out here)

    func testTheOvernightIntentionReadsBackFirst() {
        var c = ctx(programDay: 9, feeling: "proud")
        c.morningIntention = "tomorrow at breakfast: 30 g of protein, before anything else."
        let brief = DailyBriefEngine.brief(for: c)
        XCTAssertTrue(brief.second?.contains("you set this last night") ?? false)
        XCTAssertTrue(brief.second?.contains("30 g of protein") ?? false,
                      "her accepted plan, verbatim — and it outranks the proud seasoning")
    }

    func testNoIntentionMeansNoReadBack() {
        let brief = DailyBriefEngine.brief(for: ctx(programDay: 9))
        XCTAssertFalse(brief.second?.contains("last night") ?? false)
    }

    func testCarriesIntentionFlagIsTruthful() {
        // The analytics flag mirrors the render, not the stored key —
        // true exactly when the read-back sentence stands.
        var c = ctx(programDay: 9)
        c.morningIntention = "tomorrow at breakfast: 30 g of protein, before anything else."
        XCTAssertTrue(DailyBriefEngine.brief(for: c).carriesIntention)
        XCTAssertFalse(DailyBriefEngine.brief(for: ctx(programDay: 9)).carriesIntention)
        // Displaced by a real second sentence → the flag stays false
        // (the intention did NOT read back; reporting it would lie).
        var displaced = ctx(programDay: 2, plates: 2, protein: 76)
        displaced.morningIntention = "tomorrow at breakfast: 30 g of protein, before anything else."
        let brief = DailyBriefEngine.brief(for: displaced)
        XCTAssertTrue(brief.second?.contains("protein on record") ?? false,
                      "day_two's own second must win, or this case tests nothing")
        XCTAssertFalse(brief.carriesIntention)
    }

    // — the proud seasoning (L2)

    func testProudFinallyGetsReadBack() {
        // programDay 9 → archetype fallback (no second) → seasoning.
        let brief = DailyBriefEngine.brief(for: ctx(programDay: 9, feeling: "proud"))
        XCTAssertTrue(brief.second?.contains("proud") ?? false)
    }

    func testProudNeverOverwritesARealSecondSentence() {
        let brief = DailyBriefEngine.brief(for: ctx(
            programDay: 2, plates: 2, protein: 76, feeling: "proud"
        ))
        // day_two's own second (protein on record) wins; proud rides
        // the receipt instead.
        XCTAssertTrue(brief.second?.contains("protein on record") ?? false)
        XCTAssertTrue(brief.receipt?.ledgerLine.contains("closed proud") ?? false)
    }

    func testOkayStaysAQuietReceiptWord() {
        let brief = DailyBriefEngine.brief(for: ctx(programDay: 9, feeling: "okay"))
        XCTAssertFalse(brief.second?.contains("okay") ?? false)
        XCTAssertTrue(brief.receipt?.ledgerLine.contains("closed okay") ?? false)
    }

    // — the kept promise (L1)

    func testPromiseKeptOutranksEverything() {
        let brief = DailyBriefEngine.brief(for: ctx(
            programDay: 2, plates: 2, protein: 76, promiseKept: true
        ))
        XCTAssertEqual(brief.clause, "promise_kept")
        // And the receipt still shows the evidence.
        XCTAssertNotNil(brief.receipt)
    }
}
