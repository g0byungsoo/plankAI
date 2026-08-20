import XCTest
@testable import plankAI

// MARK: - Pass55MethodCollisionTests (pass 55 §6)
//
// Two or more triggers simultaneously eligible, asked ONE question:
// why did jeni tell her THIS, TODAY? The answer must be deterministic —
// the priority list, the cooldown ledger and the stand-downs decide,
// never iteration order or luck. Each test is a collision the pass-54
// histories did not pin.

final class Pass55MethodCollisionTests: XCTestCase {

    /// The same quiet base the adversarial histories use.
    private func base() -> MethodEngine.Input {
        var i = MethodEngine.Input()
        i.plateCountEver = 40
        i.proteinEatenTodayG = 70
        i.proteinFloorG = 90
        i.recentLoggedDayProteins = [95, 92, 98, 91, 94]
        i.metProteinFloorBeforeToday = true
        i.loggedDayOffsets = Set(0..<7)
        i.weekendDayOffsets = [2, 3]
        i.programDay = 30
        i.hourOfDay = 10
        i.trendIsEstablished = true
        i.weighInCount = 12
        i.emaDelta7dKg = -0.2
        i.daysOfWeightHistory = 40
        i.latestWeightKg = 74.0
        i.previousWeightKg = 74.1
        i.strengthSessionsLast7 = 2
        i.steps7dMean = 7_000
        i.steps28dMean = 7_200
        return i
    }

    /// A frightening morning where BOTH explanations are true: 3,400 mg
    /// of sodium yesterday AND the first days of her period. Salt wins —
    /// yesterday's dinner is the more specific fact — and exactly one
    /// note renders.
    func testSaltAndMensesOnTheSameMorning_SaltIsTheMoreSpecificFact() {
        var i = base()
        i.latestWeightKg = 74.7
        i.previousWeightKg = 74.0
        i.lastWeighInDaysAgo = 0
        i.emaDelta7dKg = 0.0
        i.yesterdaySodiumMg = 3_400
        i.cycleSeasonIsMenstrual = true
        let note = MethodEngine.note(i)
        XCTAssertEqual(note?.note.trigger, .saltyDinnerScaleBump)
        // Both explanations are TRUE; the surface shows one.
        XCTAssertEqual(
            Array(MethodEngine.activeTriggers(i).prefix(2)),
            [.saltyDinnerScaleBump, .mensesOnsetScaleBump]
        )
    }

    /// The same double-explanation morning with every salty note inside
    /// its cooldown: the engine falls through to the NEXT true
    /// explanation rather than to silence — she still gets an answer,
    /// just never the same one twice in a week.
    func testSaltOnCooldown_TheCycleExplanationSpeaksInstead() {
        var i = base()
        i.latestWeightKg = 74.7
        i.previousWeightKg = 74.0
        i.lastWeighInDaysAgo = 0
        i.emaDelta7dKg = 0.0
        i.yesterdaySodiumMg = 3_400
        i.cycleSeasonIsMenstrual = true
        i.shownDaysAgoById = [
            "salty_dinner_scale_v1": 2,
            "salty_dinner_pattern_v1": 2,
        ]
        XCTAssertEqual(
            MethodEngine.note(i)?.note.trigger, .mensesOnsetScaleBump,
            "a cooled-down explanation yields to the next true one, not to silence"
        )
    }

    /// A q10d user in her waning band (day 9 of 10) on a day the
    /// adequacy net is already speaking: the rhythm teaching stands
    /// down. One hard day, one voice — the interval user gets the same
    /// protection the weekly user gets.
    func testWaningBandDefersToTheAdequacyNet_ForIntervalRhythms() {
        var i = base()
        i.doseCycleDay = 9
        i.doseCycleLength = 10
        i.adequacyNetShowing = true
        XCTAssertNil(MethodEngine.note(i))
        i.adequacyNetShowing = false
        XCTAssertEqual(
            MethodEngine.note(i)?.note.trigger, .lateInDoseWeek,
            "control: without the net, day 9 of 10 IS the waning teaching"
        )
    }

    /// Queasy AND constipated in the same window: the fluid note wins —
    /// it is the only trigger whose subject is a named safety mechanism,
    /// and it is true for a day or two at most.
    func testQueasyAndConstipated_FluidsOutrankTheFiberTeaching() {
        var i = base()
        i.recentQueasySymptomWord = "queasy"
        i.loggedConstipationRecently = true
        i.recentFiberGPerDay = 12
        let note = MethodEngine.note(i)
        XCTAssertEqual(note?.note.trigger, .fluidsOnAQueasyDay)
        XCTAssertEqual(
            Array(MethodEngine.activeTriggers(i).prefix(2)),
            [.fluidsOnAQueasyDay, .constipationWithLowFiber]
        )
    }

    /// She deliberately ended her medication ten days ago AND the scale
    /// jumped against a flat line this morning. The morning that
    /// frightens her is answerable only today; the ended-support note
    /// keeps for weeks and fires tomorrow.
    func testEndedMedicationAndAJump_TheMorningIsAnsweredFirst() {
        var i = base()
        i.selfMedicationEndedDaysAgo = 10
        i.latestWeightKg = 74.9
        i.previousWeightKg = 74.0
        i.lastWeighInDaysAgo = 0
        i.emaDelta7dKg = 0.0
        XCTAssertEqual(
            MethodEngine.note(i)?.note.trigger, .weightJumpedAgainstTrend
        )
        // Tomorrow, with the jump absorbed, the support note is next.
        var tomorrow = i
        tomorrow.latestWeightKg = 74.2
        tomorrow.previousWeightKg = 74.9
        tomorrow.shownDaysAgoById = ["scale_vs_trend_v1": 1]
        XCTAssertEqual(
            MethodEngine.note(tomorrow)?.note.trigger, .medicationRecentlyEnded
        )
    }

    /// A q10d user, waning band, salty dinner yesterday, bump this
    /// morning: the specific explanation (salt) outranks the phase
    /// teaching (waning) — she is told why the SCALE moved, not why
    /// her appetite might.
    func testIntervalWaningPlusSaltyBump_TheScaleQuestionWins() {
        var i = base()
        i.doseCycleDay = 9
        i.doseCycleLength = 10
        i.latestWeightKg = 74.6
        i.previousWeightKg = 74.0
        i.lastWeighInDaysAgo = 0
        i.emaDelta7dKg = 0.0
        i.yesterdaySodiumMg = 3_100
        XCTAssertEqual(
            MethodEngine.note(i)?.note.trigger, .saltyDinnerScaleBump
        )
    }

    /// The kitchen sink: seven triggers simultaneously true. Exactly one
    /// note renders, it is the highest-priority eligible one, and the
    /// active list is ordered by the pinned priority — determinism under
    /// maximum collision.
    func testKitchenSink_ExactlyOneNoteAndAPinnedOrder() {
        var i = base()
        i.recentQueasySymptomWord = "queasy"          // fluids
        i.yesterdaySodiumMg = 3_400                    // salty
        i.cycleSeasonIsMenstrual = true                // menses
        i.latestWeightKg = 74.9                        // bump + jump
        i.previousWeightKg = 74.0
        i.lastWeighInDaysAgo = 0
        i.emaDelta7dKg = 0.0
        i.selfMedicationEndedDaysAgo = 5               // ended
        i.loggedConstipationRecently = true            // constipation
        i.recentFiberGPerDay = 12
        i.flatWeeks = 3                                // plateau... but
        // emaDelta 0.0 is inside the flat band story; trend established.
        let active = MethodEngine.activeTriggers(i)
        XCTAssertGreaterThanOrEqual(active.count, 6)
        XCTAssertEqual(
            active,
            MethodEngine.priority.filter { active.contains($0) },
            "the active list must be the priority list filtered, nothing reordered"
        )
        XCTAssertEqual(
            MethodEngine.note(i)?.note.trigger, active.first,
            "the note is the head of the eligible list — never a lottery"
        )
    }
}
