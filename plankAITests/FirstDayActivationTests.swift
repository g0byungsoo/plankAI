import XCTest
@testable import plankAI

// MARK: - FirstDayActivationTests (pass 52 — THE FIRST DAY)
//
// The activation corridor's laws as executable tests: what stands
// between a successful purchase and the first trusted record, and what
// the product does the moment that record exists. Each engine here is
// the ONE copy its view reads, so a green suite pins the real product.
final class FirstDayActivationTests: XCTestCase {

    // MARK: 1 · the corridor — purchase → Home carries no detours

    func testTheCorridorRunsForgingToCoachToFinish() {
        XCTAssertEqual(
            PostPurchaseCorridor.next(after: .forging, hasPromise: false),
            .coachIntro
        )
        XCTAssertEqual(
            PostPurchaseCorridor.next(after: .coachIntro, hasPromise: false),
            .finish,
            "the corridor must hand her to the product after the coach's one beat — the breathwork primer was a teaching detour in the activation minute"
        )
    }

    func testTheConsultsOwnOathStillReplaysBeforeTheFinish() {
        // The v8 consult seals a day-1 promise pre-wall; the corridor
        // replays her own words once, then finishes.
        XCTAssertEqual(
            PostPurchaseCorridor.next(after: .coachIntro, hasPromise: true),
            .promiseConfirmation
        )
        XCTAssertEqual(
            PostPurchaseCorridor.next(after: .promiseConfirmation, hasPromise: true),
            .finish
        )
    }

    // MARK: 2 · the coach's last beat is a handoff, not a stale promise

    func testTheCoachIntroEndsInTheSentenceHandoff() {
        XCTAssertTrue(
            CoachIntroView.handoffLine.contains("sentence")
                || CoachIntroView.handoffSub.contains("sentence"),
            "the intro's close must arm the words door — the cheapest record in the product"
        )
        XCTAssertFalse(
            CoachIntroView.handoffLine.contains("five minutes"),
            "'today. five minutes.' promised the workout era; this build's first action is a sentence"
        )
        for line in [CoachIntroView.handoffLine, CoachIntroView.handoffSub] {
            XCTAssertFalse(line.contains("\u{2014}"), "em-dash banned: \(line)")
            XCTAssertEqual(line, line.lowercased(), "lowercase voice: \(line)")
        }
    }

    // MARK: 3 · the setup subflow — one decision, then Home

    func testATierlessArrivalStartsOnThePaceDecision() {
        XCTAssertEqual(
            SubflowPagePlan.firstPage(hasPickedTier: false), .pace,
            "the goal-date explainer asked nothing; the pace pick is the one decision the consult did not collect"
        )
    }

    func testAPrePickedTierArrivalKeepsItsSingleConfirmationPage() {
        // Control: the real v8 payer (pace picked pre-wall) still gets
        // exactly one page.
        XCTAssertEqual(SubflowPagePlan.firstPage(hasPickedTier: true), .commitment)
        XCTAssertTrue(SubflowPagePlan.commits(on: .commitment))
    }

    func testThePacePageCommitsDirectly() {
        XCTAssertTrue(
            SubflowPagePlan.commits(on: .pace),
            "picking a pace and starting must be ONE page — a separate ceremony screen is a screen between her and the record"
        )
        XCTAssertEqual(SubflowPagePlan.ctaTitle(for: .pace), "i'm in")
    }

    // MARK: 4 · the day-one contract — the notification moment

    private func contract(
        answered: Bool = false, askAvailable: Bool = true,
        records: Int = 1, dose: Bool = false
    ) -> DayOneContract.Decision {
        DayOneContract.decide(.init(
            answered: answered, osAskAvailable: askAvailable,
            recordsToday: records, wantsDoseReminder: dose
        ))
    }

    func testTheContractShowsAfterTheFirstRecord() {
        guard case .show(let line, let ask) = contract() else {
            return XCTFail("the day-one contract must exist after the first record — R1's close")
        }
        XCTAssertTrue(line.contains("read it back"),
                      "the promise names the real payout: \(line)")
        XCTAssertTrue(ask.contains("quiet reminder"),
                      "the ask is an offer in the product's voice: \(ask)")
    }

    func testTheContractNeverShowsBeforeARecordExists() {
        XCTAssertEqual(
            contract(records: 0), .hidden,
            "a promise about nothing is a nag — the card waits for a record to be about"
        )
    }

    func testTheContractRespectsTheOSAnswer() {
        XCTAssertEqual(
            contract(askAvailable: false), .hidden,
            "once the OS ask is spent (granted OR denied), the card never renders — no punishment, no Settings chase"
        )
    }

    func testTheContractIsAnsweredAtMostOnce() {
        XCTAssertEqual(contract(answered: true), .hidden)
    }

    func testTheGLP1VariantNamesTheShotNudgeOnlyForHer() {
        guard case .show(_, let ask) = contract(dose: true) else {
            return XCTFail("glp-1 variant missing")
        }
        XCTAssertTrue(ask.contains("shot-day"),
                      "one ask covers both notes for a medicated user: \(ask)")
        guard case .show(_, let plainAsk) = contract(dose: false) else {
            return XCTFail()
        }
        XCTAssertFalse(plainAsk.contains("shot"),
                       "a non-medicated user never meets medication words")
    }

    func testTheContractCopyKeepsTheVoiceLaws() {
        guard case .show(let line, let ask) = contract(dose: true) else {
            return XCTFail()
        }
        for s in [line, ask] {
            XCTAssertFalse(s.contains("\u{2014}"), "em-dash banned: \(s)")
            XCTAssertFalse(s.contains("AI"), "the product never says AI: \(s)")
            XCTAssertEqual(s, s.lowercased(), "lowercase voice: \(s)")
            XCTAssertFalse(s.lowercased().contains("streak"), "no streak language")
        }
    }
}
