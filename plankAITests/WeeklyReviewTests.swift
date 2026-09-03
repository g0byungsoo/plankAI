import XCTest
@testable import plankAI

// MARK: - WeeklyReviewTests
//
// docs/app_v4/01_PROGRAM.md §0 — the re-signing's laws: due only at
// week boundaries and never twice; proposals come from the closed
// set, respect suppression + clamps; consent writes the knobs the
// engines read; the week story is provenance-only.

final class WeeklyReviewTests: XCTestCase {

    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "WeeklyReviewTests")
        defaults.removePersistentDomain(forName: "WeeklyReviewTests")
    }

    // MARK: - Due logic

    func testDueOnClosingEveningOfWeekOne() {
        // Program day 7 (slot 6) at 17:00 → week 1 due.
        XCTAssertEqual(
            WeeklyReview.dueWeekIndex(
                programDay: 7, hour: 17, signedWeeks: [],
                breakActive: false, elapsedDaysInWeek: { _ in 7 }
            ), 1
        )
        // Same evening, already signed → nil.
        XCTAssertNil(
            WeeklyReview.dueWeekIndex(
                programDay: 7, hour: 19, signedWeeks: [1],
                breakActive: false, elapsedDaysInWeek: { _ in 7 }
            )
        )
        // Afternoon of day 7 → not yet.
        XCTAssertNil(
            WeeklyReview.dueWeekIndex(
                programDay: 7, hour: 14, signedWeeks: [],
                breakActive: false, elapsedDaysInWeek: { _ in 7 }
            )
        )
    }

    func testDueWindowCarriesIntoNextWeek() {
        // Days 8-10 (slots 0-2 of week 2) still offer week 1.
        for day in 8...10 {
            XCTAssertEqual(
                WeeklyReview.dueWeekIndex(
                    programDay: day, hour: 9, signedWeeks: [],
                    breakActive: false, elapsedDaysInWeek: { _ in 7 }
                ), 1, "day \(day) should offer week 1"
            )
        }
        // Day 11 (slot 3) — the window closed; no stale review.
        XCTAssertNil(
            WeeklyReview.dueWeekIndex(
                programDay: 11, hour: 9, signedWeeks: [],
                breakActive: false, elapsedDaysInWeek: { _ in 7 }
            )
        )
    }

    func testNeverDueOnBreakOrThinWeeks() {
        XCTAssertNil(
            WeeklyReview.dueWeekIndex(
                programDay: 8, hour: 9, signedWeeks: [],
                breakActive: true, elapsedDaysInWeek: { _ in 7 }
            )
        )
        // A 2-day stub week (mid-week data wipe / enrollment edge).
        XCTAssertNil(
            WeeklyReview.dueWeekIndex(
                programDay: 8, hour: 9, signedWeeks: [],
                breakActive: false, elapsedDaysInWeek: { _ in 2 }
            )
        )
    }

    // MARK: - Proposal rules

    private func inputs(
        chapter: Chapter = .losing,
        phaseKey: ArcPhase.Key = .build,
        zone: BandZone? = nil,
        suppressed: Bool = false,
        restrictive: Bool = false,
        proteinTarget: Int? = 90,
        proteinAdjust: Int = 0,
        sessionsPlanned: Int = 4,
        sessionsAdjust: Int = 0,
        movedDays: Int = 2,
        weighs: Int = 1,
        priorWeighs: Int? = 1,
        proteinDaysMet: Int = 3,
        plateLoggedDays: Int = 5,
        kept: Int = 4,
        elapsed: Int = 7
    ) -> WeeklyReview.ProposalInputs {
        WeeklyReview.ProposalInputs(
            chapter: chapter, phaseKey: phaseKey, zone: zone,
            numericsSuppressed: suppressed, restrictiveRisk: restrictive,
            proteinTargetG: proteinTarget, proteinAdjustG: proteinAdjust,
            sessionsPlanned: sessionsPlanned, sessionsAdjust: sessionsAdjust,
            movedDays: movedDays, weighCount: weighs,
            priorWeekWeighCount: priorWeighs,
            proteinDaysMet: proteinDaysMet,
            plateLoggedDays: plateLoggedDays,
            keptCount: kept,
            elapsedDays: elapsed
        )
    }

    func testSteadyWeekProposesHold() {
        let proposal = WeeklyReview.propose(inputs())
        guard case .holdSteady(let reason) = proposal else {
            return XCTFail("expected holdSteady, got \(proposal.key)")
        }
        XCTAssertTrue(reason.contains("4 kept days"), reason)
        // p70 — the title says "the plan holds steady"; a reason that
        // repeats "the plan holds" says the same thing twice on one
        // screen (the doubled-sentence class, filmed on the read).
        XCTAssertFalse(reason.contains("the plan holds"), reason)
    }

    /// p70 — the quiet-week hold carries evidence, not an echo of the
    /// title above it.
    func testQuietWeekHoldDoesNotRepeatTheTitle() {
        let proposal = WeeklyReview.propose(inputs(kept: 1))
        guard case .holdSteady(let reason) = proposal else {
            return XCTFail("expected holdSteady, got \(proposal.key)")
        }
        XCTAssertFalse(reason.contains("the plan holds"), reason)
    }

    func testUnreachableProteinFloorEases() {
        let proposal = WeeklyReview.propose(
            inputs(proteinDaysMet: 1, elapsed: 7)
        )
        guard case .proteinEase(let g, _) = proposal else {
            return XCTFail("expected proteinEase, got \(proposal.key)")
        }
        XCTAssertEqual(g, 85)
    }

    func testThinPlateDataNeverSpeaksProtein() {
        // One logged day: "the floor was out of reach" would be a
        // claim about absent data. The rules stay quiet.
        let proposal = WeeklyReview.propose(
            inputs(proteinDaysMet: 0, plateLoggedDays: 1)
        )
        XCTAssertFalse(["protein_ease", "protein_firm"].contains(proposal.key),
                       "thin data got \(proposal.key)")
    }

    func testClearedFloorFirmsGently() {
        let proposal = WeeklyReview.propose(inputs(proteinDaysMet: 5))
        guard case .proteinFirm(let g, _) = proposal else {
            return XCTFail("expected proteinFirm, got \(proposal.key)")
        }
        XCTAssertEqual(g, 95)
    }

    func testSuppressedNumericsNeverProposeNumbers() {
        let ease = WeeklyReview.propose(
            inputs(suppressed: true, proteinDaysMet: 0)
        )
        XCTAssertFalse(["protein_ease", "protein_firm"].contains(ease.key),
                       "suppressed cohort got \(ease.key)")
        let firm = WeeklyReview.propose(
            inputs(suppressed: true, proteinDaysMet: 7)
        )
        XCTAssertFalse(["protein_ease", "protein_firm"].contains(firm.key))
    }

    func testRestrictiveRiskNeverFirmsTheFloor() {
        let proposal = WeeklyReview.propose(
            inputs(restrictive: true, proteinDaysMet: 6)
        )
        XCTAssertNotEqual(proposal.key, "protein_firm")
    }

    func testZeroMovementEases() {
        let proposal = WeeklyReview.propose(inputs(movedDays: 0))
        guard case .movesEase(let n, _) = proposal else {
            return XCTFail("expected movesEase, got \(proposal.key)")
        }
        XCTAssertEqual(n, 3)
    }

    func testTwoQuietWeighWeeksSoften() {
        let proposal = WeeklyReview.propose(
            inputs(weighs: 0, priorWeighs: 0)
        )
        XCTAssertEqual(proposal.key, "weigh_soften")
    }

    func testBendOffersTheAnglePick() {
        let proposal = WeeklyReview.propose(inputs(phaseKey: .bend))
        guard case .intentPick(let options, _) = proposal else {
            return XCTFail("expected intentPick, got \(proposal.key)")
        }
        XCTAssertEqual(options.map(\.key),
                       ["steady_week", "fresh_angle", "protein_week"])
    }

    func testKeepingZoneWeeksHoldEverythingElse() {
        let proposal = WeeklyReview.propose(
            inputs(chapter: .keeping, phaseKey: .kept, zone: .drifting,
                   movedDays: 0, proteinDaysMet: 0)
        )
        XCTAssertEqual(proposal.key, "hold_steady")
    }

    // MARK: - Consent application (clamps + knobs)

    func testProteinAdjustClampsAtPlusMinusTen() {
        for _ in 0..<5 {
            WeeklyReview.apply(.proteinEase(newG: 0, reason: ""), forWeek: 1, defaults)
        }
        XCTAssertEqual(defaults.integer(forKey: WeeklyReview.proteinAdjustKey), -10)
        for _ in 0..<8 {
            WeeklyReview.apply(.proteinFirm(newG: 0, reason: ""), forWeek: 1, defaults)
        }
        XCTAssertEqual(defaults.integer(forKey: WeeklyReview.proteinAdjustKey), 10)
    }

    func testIntentPickWritesNextWeeksKey() {
        let stamp = WeeklyReview.apply(
            .intentPick(options: [], reason: ""),
            forWeek: 6, chosenIntentKey: "steady_week", defaults
        )
        XCTAssertEqual(
            defaults.string(forKey: WeeklyReview.intentPickKey(week: 7)),
            "steady_week"
        )
        XCTAssertEqual(stamp, "next week: the steady week")
    }

    func testAdjustedProteinStaysInsideAdvisoryBand() {
        // A 50kg default-cohort user: 1.2 g/kg = 60 → floor-clamped
        // to 70. An eased adjust (−10) cannot take the target below
        // the advisory floor.
        XCTAssertEqual(TargetsService.proteinTargetG(weightKg: 50, adjustG: -10), 70)
        // A 110kg user clamps at the hi bound even firmed up.
        XCTAssertEqual(TargetsService.proteinTargetG(weightKg: 110, adjustG: 10), 130)
        // Mid-band, the adjust applies exactly.
        XCTAssertEqual(TargetsService.proteinTargetG(weightKg: 75, adjustG: 0), 90)
        XCTAssertEqual(TargetsService.proteinTargetG(weightKg: 75, adjustG: 5), 95)
    }

    // MARK: - Week story (provenance-only)

    private func slice(
        kept: Int, plates: Int, weighs: Int, reps: Int = 0, paused: Int = 0
    ) -> ProgramWeekSlice {
        var days: [ProgramWeekSlice.DayFact] = []
        for i in 0..<7 {
            days.append(ProgramWeekSlice.DayFact(
                programDay: i + 1, dayKey: "2026-07-0\(i + 1)",
                date: .distantPast, isFuture: false,
                isPaused: i < paused,
                completedCount: i < kept ? 3 : 0,
                oneThingDone: false,
                plateCount: i < plates ? 1 : 0,
                proteinG: 0,
                weighKg: i < weighs ? 70.0 : nil,
                repKept: i < reps
            ))
        }
        return ProgramWeekSlice(weekIndex: 1, days: days)
    }

    func testWeekStorySpeaksOnlyCountedFacts() {
        let story = WeeklyReview.weekStory(
            slice: slice(kept: 3, plates: 5, weighs: 2), chapter: .losing
        )
        XCTAssertEqual(story, "3 days kept · 5 plates logged · weighed in 2 times.")
    }

    func testQuietWeekIsAFactNotAVerdict() {
        let story = WeeklyReview.weekStory(
            slice: slice(kept: 0, plates: 0, weighs: 0), chapter: .losing
        )
        XCTAssertEqual(story, "a quiet week. nothing logged.")
    }

    func testHeldWeekNamesTheKeptPlace() {
        let story = WeeklyReview.weekStory(
            slice: slice(kept: 0, plates: 0, weighs: 0, paused: 6), chapter: .losing
        )
        XCTAssertEqual(story, "a break week. plan paused.")
    }

    // MARK: - Standing derivation through the slice

    func testDayFactStandingMatchesSpineGrammar() {
        let fact = ProgramWeekSlice.DayFact(
            programDay: 1, dayKey: "k", date: .now, isFuture: false,
            isPaused: false, completedCount: 2, oneThingDone: true,
            plateCount: 0, proteinG: 0, weighKg: nil, repKept: false
        )
        XCTAssertEqual(fact.standing, .kept)   // one thing + 2 = kept
    }
}
