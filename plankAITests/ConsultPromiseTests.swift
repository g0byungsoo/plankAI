import XCTest
@testable import plankAI

// Pass 57 (W3a) — THE CONSULT KEEPS ITS PROMISES.
//
// The v8 hormonal beat answers, in second person:
//   perimenopause · postmenopause →
//     "noted. the plan uses the *gentler* pace your body needs here."
//   postpartum →
//     "noted. the pace stays *protective* here."
//
// Until this pass, only "perimenopause" changed anything: the
// calculator's predicate matched that one string, so a postmenopausal
// or postpartum woman was told the pace would be gentler and got the
// default 0.5%/wk — a promise made to her face and dropped in the
// arithmetic. This suite states the promise as law: every stage the
// consult answers with a pace sentence runs the cautious floor, and
// locks the Hard tier the same way perimenopause always has.
final class ConsultPromiseTests: XCTestCase {

    /// The stages the consult's own ack copy promises a gentler or
    /// protective pace to — transcribed from V8Beats "hormonal".
    private let promisedStages = ["perimenopause", "postmenopause", "postpartum"]

    func testEveryStageTheConsultAnswersWithAPaceSentenceRunsTheCautiousFloor() {
        for stage in promisedStages {
            let window = ProgramGoalCalculator.compute(.init(
                currentWeightKg: 90,
                goalWeightKg: 80,
                sex: .female,
                age: 34,
                hasGentlerPaceStage: ProgramGoalCalculator.gentlerPaceStage(from: stage)
            ))
            XCTAssertEqual(window.lossRateFloor, 0.003, accuracy: 0.0001,
                           "\(stage): the consult said 'gentler'; the plan ran \(window.lossRateFloor)")
        }
    }

    func testStagesWithoutAPaceSentenceKeepTheDefaultFloor() {
        for stage in ["cycling", "irregular", "prefer_not_say", ""] {
            let window = ProgramGoalCalculator.compute(.init(
                currentWeightKg: 90,
                goalWeightKg: 80,
                sex: .female,
                age: 34,
                hasGentlerPaceStage: ProgramGoalCalculator.gentlerPaceStage(from: stage)
            ))
            XCTAssertEqual(window.lossRateFloor, 0.005, accuracy: 0.0001,
                           "\(stage) was never promised a pace change")
        }
    }

    func testPromisedStagesLockTheHardTier() {
        for stage in promisedStages {
            let unlocked = HardTierGate.isUnlocked(.init(
                isGLP1User: false,
                hasGentlerPaceStage: ProgramGoalCalculator.gentlerPaceStage(from: stage),
                age: 34,
                activityLevel: .moderate
            ))
            XCTAssertFalse(unlocked,
                           "\(stage): 'protective' cannot include the 1%/wk tier")
        }
    }

    func testAnUnpromisedStageAloneDoesNotLockHard() {
        let unlocked = HardTierGate.isUnlocked(.init(
            isGLP1User: false,
            hasGentlerPaceStage: ProgramGoalCalculator.gentlerPaceStage(from: "cycling"),
            age: 34,
            activityLevel: .moderate
        ))
        XCTAssertTrue(unlocked)
    }
}

// MARK: - The week-three promise (W3b)
//
// "then you know week three is where it usually breaks. we plan for
// that." — the prior-attempts ack, verbatim. The weekly read is the
// plan's voice, so the read keeps the sentence at the exact week the
// consult named, once, only for someone who told us she'd been here.
extension ConsultPromiseTests {

    private func weekInputs(
        week: Int?, saidPriorAttempts: Bool,
        offer: WeeklyReadOffer = .v4(.holdSteady(reason: "the plan holds."))
    ) -> WeeklyReadComposer.Inputs {
        var i = WeeklyReadComposer.Inputs(
            windowStartDay: "2026-08-03",
            anchorKind: .doseDay,
            offer: offer
        )
        i.stepsThisWeek = Array(repeating: 6_000, count: 7)
        i.plateDays = 5
        i.plateCount = 10
        i.proteinDaysMet = 4
        i.programWeek = week
        i.saidPriorAttempts = saidPriorAttempts
        return i
    }

    private var weekThreeLine: String {
        "week three. the one that usually breaks a fresh start. this one is planned for. nothing to win back, the week just continues."
    }

    func testWeekThreeSpeaksThePromiseToSomeoneWhoTriedBefore() {
        let model = WeeklyReadComposer.compose(
            weekInputs(week: 3, saidPriorAttempts: true))
        XCTAssertEqual(model.teaching, weekThreeLine)
    }

    func testWeekThreeStaysQuietForACleanStart() {
        let model = WeeklyReadComposer.compose(
            weekInputs(week: 3, saidPriorAttempts: false))
        XCTAssertNotEqual(model.teaching, weekThreeLine)
    }

    func testThePromiseSpeaksOnlyInWeekThree() {
        for week in [1, 2, 4, 10] {
            let model = WeeklyReadComposer.compose(
                weekInputs(week: week, saidPriorAttempts: true))
            XCTAssertNotEqual(model.teaching, weekThreeLine, "week \(week)")
        }
    }

    /// The medicated voice keeps precedence: a waning-band week is a
    /// truth about her body this week; the week-three sentence can
    /// wait for a read with room.
    func testTheWaningTeachingOutranksTheWeekThreeSentence() {
        var i = weekInputs(week: 3, saidPriorAttempts: true)
        i.doseWeek = .takenOnDay
        i.cycleDay = 9
        i.cycleLength = 10
        let model = WeeklyReadComposer.compose(i)
        XCTAssertEqual(
            model.teaching,
            "the last days of a dose rhythm often run hungrier. that's the shape of the rhythm, not a slip."
        )
    }
}
