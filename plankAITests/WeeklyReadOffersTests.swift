import XCTest
import SwiftData
@testable import plankAI

// E1 THE SPINE — the read's offer engine (docs/app_v25/05_E1_SPINE
// §2). The v4 closed set leads (delegation preserves its laws); the
// spine adds the step-goal recalc + the sparse-week logging lighten.
// ONE offer, conservative, cooldown-aware.

final class WeeklyReadOffersTests: XCTestCase {

    private func quietV4(
        proteinTarget: Int? = 90,
        proteinDaysMet: Int = 3,
        plateLoggedDays: Int = 5,
        elapsedDays: Int = 7,
        keptCount: Int = 4
    ) -> WeeklyReview.ProposalInputs {
        .init(
            chapter: .losing,
            phaseKey: .build,
            zone: nil,
            numericsSuppressed: false,
            restrictiveRisk: false,
            proteinTargetG: proteinTarget,
            proteinAdjustG: 0,
            sessionsPlanned: 2,
            sessionsAdjust: 0,
            movedDays: 1,
            weighCount: 2,
            priorWeekWeighCount: 2,
            proteinDaysMet: proteinDaysMet,
            plateLoggedDays: plateLoggedDays,
            keptCount: keptCount,
            elapsedDays: elapsedDays
        )
    }

    private func spine(
        currentStepGoal: Int? = 6_000,
        stepRecommendation: Int? = nil,
        loggingModeWord: String? = nil,
        declined: Set<String> = []
    ) -> WeeklyReadOffers.SpineInputs {
        .init(
            currentStepGoal: currentStepGoal,
            stepGoalRecommendation: stepRecommendation,
            loggingModeWord: loggingModeWord,
            recentlyDeclinedKinds: declined
        )
    }

    // MARK: - Priority

    func testV4ClinicalRulesLeadTheOffer() {
        // Protein reachability (v4's hero rule) outranks the recalc.
        let offer = WeeklyReadOffers.propose(
            v4: quietV4(proteinDaysMet: 1),
            spine: spine(stepRecommendation: 5_000)
        )
        XCTAssertEqual(offer.key, "protein_ease")
    }

    func testStepRecalcOffersWhenMeaningful() {
        let offer = WeeklyReadOffers.propose(
            v4: quietV4(),
            spine: spine(currentStepGoal: 6_000, stepRecommendation: 5_150)
        )
        guard case .stepGoalRecalc(let newGoal, let reason) = offer else {
            return XCTFail("expected recalc, got \(offer)")
        }
        XCTAssertEqual(newGoal, 5_150)
        XCTAssertFalse(reason.isEmpty)
    }

    func testFirstGoalOffersWithoutCurrent() {
        // No owned goal yet — the recalc IS the walking action's
        // consented onboarding.
        let offer = WeeklyReadOffers.propose(
            v4: quietV4(),
            spine: spine(currentStepGoal: nil, stepRecommendation: 5_150)
        )
        guard case .stepGoalRecalc(let newGoal, _) = offer else {
            return XCTFail("expected first-goal recalc, got \(offer)")
        }
        XCTAssertEqual(newGoal, 5_150)
    }

    func testStepRecalcSilentWhenChangeTiny() {
        let offer = WeeklyReadOffers.propose(
            v4: quietV4(),
            spine: spine(currentStepGoal: 6_000, stepRecommendation: 5_900)
        )
        XCTAssertEqual(offer.key, "hold_steady")
    }

    func testStepRecalcSilentWithoutRecommendation() {
        let offer = WeeklyReadOffers.propose(
            v4: quietV4(), spine: spine(stepRecommendation: nil)
        )
        XCTAssertEqual(offer.key, "hold_steady")
    }

    func testLoggingLightenOnSparseWeek() {
        let offer = WeeklyReadOffers.propose(
            v4: quietV4(plateLoggedDays: 1, keptCount: 1),
            spine: spine(stepRecommendation: nil)
        )
        XCTAssertEqual(offer.key, "logging_lighten")
    }

    func testLoggingLightenSilentWhenAlreadyLighter() {
        let offer = WeeklyReadOffers.propose(
            v4: quietV4(plateLoggedDays: 1, keptCount: 1),
            spine: spine(loggingModeWord: "lighter")
        )
        XCTAssertEqual(offer.key, "hold_steady")
    }

    func testDeclinedKindCoolsDown() {
        let offer = WeeklyReadOffers.propose(
            v4: quietV4(),
            spine: spine(
                currentStepGoal: 6_000, stepRecommendation: 5_150,
                declined: ["step_goal_recalc"]
            )
        )
        XCTAssertEqual(offer.key, "hold_steady")
    }

    func testDefaultHoldsSteady() {
        let offer = WeeklyReadOffers.propose(v4: quietV4(), spine: spine())
        XCTAssertEqual(offer.key, "hold_steady")
    }

    // MARK: - Consent application (writes facts, never silently)

    @MainActor
    func testAcceptStepRecalcWritesAcceptedRecommendation() throws {
        let context = TestModelContainer.shared.mainContext
        let user = "e1-offer-\(UUID().uuidString)"
        let now = Date(timeIntervalSince1970: 1_754_000_000)
        WeeklyReadOffers.applyAccepted(
            .stepGoalRecalc(newGoal: 5_150, reason: "r"),
            userId: user, now: now, in: context
        )
        let head = ProgramFactStore.head(.stepGoal, userId: user, in: context)
        XCTAssertEqual(head?.value, .int(5_150))
        XCTAssertEqual(head?.authority, .recommended)
        XCTAssertNotNil(head?.acceptedAt)
    }

    @MainActor
    func testAcceptProteinEaseWritesFactAndMirrorsKnob() throws {
        let context = TestModelContainer.shared.mainContext
        let user = "e1-offer-\(UUID().uuidString)"
        let name = "e1-offer-suite-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        WeeklyReadOffers.applyAccepted(
            .v4(.proteinEase(newG: 85, reason: "r")),
            userId: user, now: .init(timeIntervalSince1970: 1_754_000_000),
            in: context, legacyDefaults: d
        )
        XCTAssertEqual(
            ProgramFactStore.headValue(.proteinAdjust, userId: user, in: context),
            .int(-5)
        )
        XCTAssertEqual(d.integer(forKey: WeeklyReview.proteinAdjustKey), -5)
    }

    @MainActor
    func testHoldSteadyWritesNoFacts() throws {
        let context = TestModelContainer.shared.mainContext
        let user = "e1-offer-\(UUID().uuidString)"
        WeeklyReadOffers.applyAccepted(
            .v4(.holdSteady(reason: "r")),
            userId: user, now: .now, in: context
        )
        XCTAssertNil(ProgramFactStore.headValue(.proteinAdjust, userId: user, in: context))
        XCTAssertNil(ProgramFactStore.headValue(.stepGoal, userId: user, in: context))
    }

    // MARK: - p79 THE LEARNED BURN (energy recalc)

    /// An established read (center 2,400, intake mean 1,900) plus a
    /// plan whose pace implies a 300 kcal/day deficit at 80 kg.
    private func energyInputs(
        centerKcal: Int = 2_400,
        intakeMean: Int = 1_900,
        target: Int? = 1_800,
        // rate × 80 kg × 7,700 / 7 = 300 kcal/day.
        rate: Double? = 300.0 * 7.0 / (7_700.0 * 80.0),
        medicated: Bool = false,
        currentAdjust: Int = 0,
        read: ExpenditureRead.Read? = nil
    ) -> WeeklyReadOffers.EnergyInputs {
        .init(
            read: read ?? .read(.init(
                bandLowKcal: centerKcal - 150, bandHighKcal: centerKcal + 150,
                centerKcal: centerKcal, usableDays: 18, windowDays: 21,
                weighInsInWindow: 12, intakeMeanKcal: intakeMean,
                weeklyMassDeltaKg: -0.4
            )),
            currentTargetKcal: target,
            planRatePctPerWeek: rate,
            currentWeightKg: 80,
            isOnMedication: medicated,
            currentAdjustKcal: currentAdjust
        )
    }

    func testEnergyRecalcWalksUpInBoundedSteps() {
        // Burn 2,400, deficit 300 → implied 2,100 vs target 1,800:
        // the +300 gap walks in a ≤150 step. Eating MORE is a first-
        // class direction (r1: never a restriction engine).
        let offer = WeeklyReadOffers.energyRecalc(energyInputs())
        guard case .energyRecalc(let newTarget, let newAdjust, _) = offer else {
            return XCTFail("expected energyRecalc, got \(String(describing: offer))")
        }
        XCTAssertEqual(newAdjust, 150)
        XCTAssertEqual(newTarget, 1_950)
    }

    func testEnergyRecalcNeverProposesDownForTheMedicatedCohort() {
        // Burn 1,900 → implied 1,600 vs target 1,800: a down step —
        // refused outright on medication (the count-up cohort, p53).
        let offer = WeeklyReadOffers.energyRecalc(energyInputs(
            centerKcal: 1_900, intakeMean: 1_800, medicated: true
        ))
        XCTAssertNil(offer)
    }

    func testEnergyRecalcNeverRatchetsAnUnderEater() {
        // Same down gap, not medicated — but her logged intake
        // already sits 400 under the target. A lower ceiling for
        // someone under the ceiling is a ratchet, not a fit.
        let offer = WeeklyReadOffers.energyRecalc(energyInputs(
            centerKcal: 1_900, intakeMean: 1_400
        ))
        XCTAssertNil(offer)
    }

    func testEnergyRecalcProposesDownForAnEaterAtTarget() {
        let offer = WeeklyReadOffers.energyRecalc(energyInputs(
            centerKcal: 1_900, intakeMean: 1_780
        ))
        guard case .energyRecalc(let newTarget, let newAdjust, _) = offer else {
            return XCTFail("expected energyRecalc, got \(String(describing: offer))")
        }
        XCTAssertEqual(newAdjust, -150)
        XCTAssertEqual(newTarget, 1_650)
    }

    func testEnergyRecalcSilentUnderMateriality() {
        // Implied 2,100 vs target 2,050 → +50 gap: not material.
        let offer = WeeklyReadOffers.energyRecalc(energyInputs(target: 2_050))
        XCTAssertNil(offer)
    }

    func testEnergyRecalcCumulativeClampSaturates() {
        // At +350 the next step lands at the ±400 rail (a +50 move);
        // at +400 the rail refuses entirely.
        let nearRail = WeeklyReadOffers.energyRecalc(energyInputs(currentAdjust: 350))
        guard case .energyRecalc(let t, let a, _) = nearRail else {
            return XCTFail("expected a rail-clamped step")
        }
        XCTAssertEqual(a, 400)
        XCTAssertEqual(t, 1_850)
        XCTAssertNil(WeeklyReadOffers.energyRecalc(energyInputs(currentAdjust: 400)))
    }

    func testEnergyRecalcSilentWithoutAnEstablishedRead() {
        XCTAssertNil(WeeklyReadOffers.energyRecalc(energyInputs(
            read: .silent(.trendNotEstablished)
        )))
        XCTAssertNil(WeeklyReadOffers.energyRecalc(energyInputs(
            read: .holding(.doseChangeFresh(daysAtDose: 5))
        )))
    }

    func testEnergyRecalcSilentOnMaintenance() {
        XCTAssertNil(WeeklyReadOffers.energyRecalc(energyInputs(rate: 0)))
        XCTAssertNil(WeeklyReadOffers.energyRecalc(energyInputs(rate: nil)))
    }

    func testEnergyOutranksStepRecalcAndCoolsDown() {
        var s = spine(stepRecommendation: 5_000)
        s.energy = energyInputs()
        let offer = WeeklyReadOffers.propose(v4: quietV4(), spine: s)
        XCTAssertEqual(offer.key, "energy_recalc")
        // Declined = cooled down for the standing window; the step
        // recalc takes the slot.
        var declined = s
        declined.recentlyDeclinedKinds = ["energy_recalc"]
        XCTAssertEqual(
            WeeklyReadOffers.propose(v4: quietV4(), spine: declined).key,
            "step_goal_recalc"
        )
    }

    func testV4ClinicalRulesStillLeadOverEnergy() {
        var s = spine()
        s.energy = energyInputs()
        let offer = WeeklyReadOffers.propose(
            v4: quietV4(proteinDaysMet: 1), spine: s
        )
        if case .energyRecalc = offer {
            XCTFail("the v4 clinical rules must outrank the energy recalc")
        }
    }

    @MainActor
    func testAcceptEnergyRecalcWritesTheDeviceKnobOnly() throws {
        let context = TestModelContainer.shared.mainContext
        let user = "e1-offer-\(UUID().uuidString)"
        let name = "p79-energy-suite-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        WeeklyReadOffers.applyAccepted(
            .energyRecalc(newTargetKcal: 1_950, newAdjustKcal: 150, reason: "r"),
            userId: user, now: .init(timeIntervalSince1970: 1_754_000_000),
            in: context, legacyDefaults: d
        )
        XCTAssertEqual(d.integer(forKey: WeeklyReview.energyAdjustKey), 150)
        // Deliberately NOT a fact kind (the server CHECK gate) — no
        // fact row may appear for any kind from this accept.
        for kind in ProgramFactKind.allCases {
            XCTAssertNil(ProgramFactStore.headValue(kind, userId: user, in: context))
        }
    }
}
