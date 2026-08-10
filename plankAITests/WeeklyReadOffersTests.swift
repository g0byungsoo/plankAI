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
}
